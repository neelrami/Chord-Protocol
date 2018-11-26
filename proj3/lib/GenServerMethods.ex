defmodule Proj3.Chord do
    @moduledoc """
        This file contains all methods related to GenServer.
    """
    use GenServer
    
    @doc """
        This function is used to initialize nodes of Chord Ring.
    """
    def init(chordState) do
        nodeIndex=Enum.at(chordState,0)
        nodeIdentifierList=Enum.at(chordState,1)
        tableSize=Enum.at(chordState,2)
        checkFlag=Enum.at(chordState,3)
        if(checkFlag==0) do
            l1=length(nodeIdentifierList)
            successorIndex=rem(nodeIndex,l1)
            successorID=Enum.at(nodeIdentifierList,successorIndex)
            predecessorIndex=rem(nodeIndex-2,l1)
            predecessorID=Enum.at(nodeIdentifierList,predecessorIndex)
            predecessorPID=nil
            successorPID=nil
            ownIdentity=Enum.at(nodeIdentifierList,nodeIndex-1)
            fingerTable = for i <- 1..tableSize do
                id=rem(Proj3.UFunctions.floatToInt(ownIdentity+:math.pow(2,i-1)),Proj3.UFunctions.floatToInt(:math.pow(2,tableSize)))
                fingerTableConstruction(nodeIdentifierList,id)
            end
            fingerTablePID=[]
            chordState=[ownIdentity,predecessorID,predecessorPID,successorID,successorPID,fingerTable,fingerTablePID]
            #IO.inspect(chordState)
            {:ok,chordState}
        else
            ownIdentity=Enum.at(chordState,0)
            successorID=-1
            predecessorID=-1
            predecessorPID=nil
            successorPID=nil
            fingerTable=[]
            fingerTablePID=[]
            chordState=[ownIdentity,predecessorID,predecessorPID,successorID,successorPID,fingerTable,fingerTablePID]
            {:ok,chordState}
        end
    end

    @doc """
        This function is used to set the Successor PID of a node in Chord Ring.
    """
    def handle_call({:setSuccessor, sid}, _from, chordState) do
        successorID=sid
        successorPID=Proj3.UFunctions.whereis(sid)
        newChordState=[Enum.at(chordState,0),Enum.at(chordState,1),Enum.at(chordState,2),successorID,successorPID,Enum.at(chordState,5),Enum.at(chordState,6)]
        {:reply, newChordState, newChordState}
    end

    @doc """
        This function is used to set Predecessor and Successor PIDs of a node in Chord Ring.
    """
    def handle_cast({:setPreSuc}, chordState) do
        predecessorPID=Proj3.UFunctions.whereis(Enum.at(chordState,1))
        successorPID=Proj3.UFunctions.whereis(Enum.at(chordState,3)) 
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),predecessorPID,Enum.at(chordState,3),successorPID,Enum.at(chordState,5),Enum.at(chordState,6)]  
        {:noreply, chordState}
    end

    @doc """
        This function is used to print a node of Chord Ring.
    """
    def handle_call({:printState}, _from, chordState) do
        IO.inspect(chordState)
        {:reply, chordState, chordState}
    end

    @doc """
        This function is used to stabilize the network.
    """
    def handle_cast({:stabilize}, chordState) do
        successorID=Enum.at(chordState,3)
        successorPID=Enum.at(chordState,4)
        ownIdentity=Enum.at(chordState,0)
        preID=getPredecessor(successorPID)
        successorID1 = if(preID>ownIdentity and preID<successorID) do
            preID
        else
            successorID
        end
        successorPID1=Proj3.UFunctions.whereis(successorID1)
        notify(successorPID1,ownIdentity)
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),Enum.at(chordState,2),successorID1,successorPID1,Enum.at(chordState,5),Enum.at(chordState,6)]
        {:noreply, chordState}
    end

    @doc """
        The below 2 functions perform the notify functionality.
    """
    def notify(successorPID1,n) do
        GenServer.cast(successorPID1,{:getnotified,n})    
    end

    def handle_cast({:getnotified,ndash}, chordState) do
        #IO.inspect("111")
        #IO.inspect(chordState)
        ownIdentity=Enum.at(chordState,0)
        predecessor=Enum.at(chordState,1)
        #IO.inspect(predecessor)
        predecessorID=if(predecessor==-1 or (ndash>predecessor and ndash<ownIdentity)) do
            ndash
        end
        predecessorPID=Proj3.UFunctions.whereis(predecessorID)
        chordState=[Enum.at(chordState,0),predecessorID,predecessorPID,Enum.at(chordState,3),Enum.at(chordState,4),Enum.at(chordState,5),Enum.at(chordState,6)]
        {:noreply,chordState}
    end

    @doc """
        The below 2 function get predecessor.
    """
    def getPredecessor(successorPID) do
        GenServer.call(successorPID,{:getPre},:infinity)
    end

    def handle_call({:getPre}, _from, chordState) do
        {:reply, Enum.at(chordState,1), chordState}
    end

    @doc """
        The below 2 functions find successor for a node.
    """
    def handle_call({:findSuccessor,keyID,myPID}, _from, chordState) do
        ownIdentity=Enum.at(chordState,0)
        successorID=Enum.at(chordState,3)
        if((keyID>ownIdentity and keyID<=successorID)==true) do
            setSuccessor(myPID,successorID)
        else
            closestPrecedingNode(keyID,myPID,chordState)
        end
        {:reply, "Successor Value Found" , chordState}
    end

    def findSuccessor(keyID,myPID,chordState) do
        ownIdentity=Enum.at(chordState,0)
        successorID=Enum.at(chordState,3)
        if((keyID>ownIdentity and keyID<=successorID)==true) do
            setSuccessor(myPID,successorID)
        else
            closestPrecedingNode(keyID,myPID,chordState)
        end
    end

    @doc """
        This function sets successor for a node.
    """
    def setSuccessor(myPID,successorID) do
        GenServer.call(myPID,{:setSuccessor,successorID}) 
    end

    @doc """
        This function finds Closest Preceding Node.
    """
    def closestPrecedingNode(keyID,myPID,chordState) do
        currentNodeIndex=Enum.at(chordState,0)
        ownPID=Proj3.UFunctions.whereis(currentNodeIndex)
        fingerTable=Enum.at(chordState,5)
        tempTable=Enum.reverse(fingerTable)
        cp=cpn1(tempTable,currentNodeIndex,keyID)
        cpPID=Proj3.UFunctions.whereis(cp)
        if(cpPID==ownPID) do
            findSuccessor(keyID,myPID,chordState)
        else
            GenServer.call(cpPID,{:findSuccessor,keyID,myPID},:infinity)
        end
    end

    def cpn1(myList,n,id) do
        [head|tail]=myList
        cond do 
            length(tail)==0 ->
                n
            head>n and head<id ->
                head
            true ->
                cpn1(tail,n,id)
        end
    end

    @doc """
        The below 2 functions are used to set Finger Table .
    """
    def handle_cast({:setFT},chordState) do
        fingerTable=Enum.at(chordState,5)
        l3=length(fingerTable)
        fingerTablePID = for i <- 1..l3 do
            Proj3.UFunctions.whereis(Enum.at(fingerTable,i-1))
        end
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),Enum.at(chordState,2),Enum.at(chordState,3),Enum.at(chordState,4),Enum.at(chordState,5),fingerTablePID]
        {:noreply,chordState}
    end

    def handle_cast({:fixFT, fingerTable}, chordState) do
        l3=length(fingerTable)
        fingerTablePID = for i <- 1..l3 do
            Proj3.UFunctions.whereis(Enum.at(fingerTable,i-1))
        end
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),Enum.at(chordState,2),Enum.at(chordState,3),Enum.at(chordState,4),fingerTable,fingerTablePID]
        {:noreply,chordState}        
    end

    def fingerTableConstruction(nodeIdentifierList,id) do
        Proj3.UFunctions.search(nodeIdentifierList,id)
    end

    @doc """
        This function processes a request.
    """
    def handle_cast({:processRequest, numRequests, nodeIdentifierList, tableSize}, chordState) do
        newList=Enum.sort(nodeIdentifierList)
        firstElement=Enum.at(newList,0)
        myL=length(newList)-1
        
        lastElement=Enum.at(newList,myL)
        currentNodeIndex=Enum.at(chordState,0)
        for i <- 1..numRequests do
            #IO.inspect(i)
            Process.sleep(1000)
            hopCount=0
            randomNumber=:rand.uniform(lastElement)
            
            #IO.inspect("Random Number "<> Integer.to_string(randomNumber))
            message="Chord Protocol" <> " Initiator " <> Integer.to_string(currentNodeIndex) <> " Key " <> Integer.to_string(randomNumber)
            #IO.inspect(message)
            startRouting(randomNumber,currentNodeIndex,chordState,message,hopCount, tableSize, lastElement, firstElement)
        end
        {:noreply, chordState}
    end


    def handle_cast({:forwardMessage, randomNumber, message, hopCount, tableSize, lastElement, firstElement}, chordState) do
        currentNodeIndex=Enum.at(chordState,0)
        startRouting(randomNumber, currentNodeIndex, chordState,message, hopCount, tableSize, lastElement, firstElement)
        {:noreply, chordState}
    end

    @doc """
        This function is used for Key Lookup.
    """
    def startRouting(randomNumber,currentNodeIndex,chordState,message,hopCount,tableSize,lastElement,firstElement) do
        #message="Chord Protocol" <> " Initiator " <> Integer.to_string(Enum.at(chordState,0)) <> " Key " <> Integer.to_string(randomNumber)
        #Process.sleep(5000)
        #IO.inspect(message)
        successorID=Enum.at(chordState,3)
        predecessorID=Enum.at(chordState,1)
        cond do
            currentNodeIndex==firstElement ->
                #generateList2(0,currentNodeIndex)
                if(randomNumber>=0 and randomNumber<=currentNodeIndex) do
                    IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                    IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                    announceHopCount(hopCount,message)
                else
                    #startIndex=currentNodeIndex+1
                    if(randomNumber>currentNodeIndex and randomNumber<=successorID) do
                        IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                        IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                        announceHopCount(hopCount+1,message)
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement)        
                    end                
                end
            currentNodeIndex==lastElement ->
                #IO.inspect(generateList2(predecessorID+1,currentNodeIndex))
                #Process.sleep(5000)
                if(randomNumber>predecessorID and randomNumber<=currentNodeIndex) do
                    IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                    IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                    announceHopCount(hopCount,message)
                else
                    #startIndex=currentNodeIndex+1
                    upperBound=Proj3.UFunctions.floatToInt(:math.pow(2,tableSize))
                    if((randomNumber>currentNodeIndex and randomNumber<upperBound) or (randomNumber>=0 and randomNumber<=successorID)) do
                        IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                        IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                        announceHopCount(hopCount+1,message)
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement)        
                    end                
                end
                #generateList2(predecessorID+1,currentNodeIndex)
                
            true ->
                if(randomNumber>predecessorID and randomNumber<=currentNodeIndex) do
                    IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                    IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                    announceHopCount(hopCount,message)
                else
                    #startIndex=currentNodeIndex+1
                    if(randomNumber>currentNodeIndex and randomNumber<=successorID) do
                        IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                        IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                        announceHopCount(hopCount+1,message)
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement)        
                    end                
                end
                #generateList2(predecessorID+1,currentNodeIndex)
        end
        
    end

    def announceHopCount(hopCount,message) do
        send :hcReceiver, {:receiveHopCount, hopCount}
    end

    def forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement,firstElement) do
        #IO.inspect("Hopcount"<>Integer.to_string(hopCount))
        fingerTable=Enum.at(chordState,5)
        tempTable=Enum.reverse(fingerTable)
        startIndex=currentNodeIndex+1
        endIndex=randomNumber-1
        abc = cond do
            randomNumber<currentNodeIndex==true ->
                #generateList(startIndex,endIndex,tableSize)
                cpn2(tempTable,startIndex,endIndex,randomNumber, currentNodeIndex, chordState,tableSize)
            randomNumber>currentNodeIndex==true ->
                #generateList2(startIndex,endIndex)
                cpn2(tempTable,startIndex,endIndex,randomNumber, currentNodeIndex, chordState)
        end

        #IO.inspect(rangeList)
        #IO.inspect("for " <> Integer.to_string(currentNodeIndex))
        #IO.inspect(abc)
        abcPID=Proj3.UFunctions.whereis(abc)
        GenServer.cast(abcPID,{:forwardMessage, randomNumber, message, hopCount+1, tableSize, lastElement, firstElement})
    end

    @doc """
        This function also finds closest preceding node.
    """
    def cpn2(fingerTable, startIndex, endIndex, key, currentNodeIndex, chordState, tableSize \\0) do
        
        [head|tail]=fingerTable
        myNum = if(key<currentNodeIndex) do
            cond do 
                length(tail)==0 ->
                    Enum.at(chordState,3)
                (head>=startIndex and head<Proj3.UFunctions.floatToInt(:math.pow(2,tableSize))) or (head>=0 and head<=endIndex) ->
                    head
                true ->
                    cpn2(tail,startIndex,endIndex,key,currentNodeIndex,chordState,tableSize)
            end
        else
            cond do 
                length(tail)==0 ->
                    Enum.at(chordState,3)
                head>=startIndex and head<=endIndex ->
                    head
                true ->
                    cpn2(tail,startIndex,endIndex,key,currentNodeIndex,chordState)
            end
        end
        
        myNum 
    end
end