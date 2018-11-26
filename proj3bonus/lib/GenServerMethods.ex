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
        l1=length(nodeIdentifierList)
        
        #Generate r successors where r=2log(n)
        
        successorNum = Proj3.UFunctions.floatToInt(logCal(l1))
        successorIDs = []
        successorIDs = 
        for i <- 1..successorNum do
            successorIDs++Enum.at(nodeIdentifierList,rem(nodeIndex+i-1,l1))
            #successorPIDs++nil
        end
        successorPIDs = []
        succcessorPIDs = 
        for i <- 1..successorNum do
            #successorIDs++Enum.at(nodeIdentifierList,i)
            successorPIDs++nil
        end
        predecessorIndex=rem(nodeIndex-2,l1)
        predecessorID=Enum.at(nodeIdentifierList,predecessorIndex)
        predecessorPID=nil
        ownIdentity=Enum.at(nodeIdentifierList,nodeIndex-1)
        fingerTable = for i <- 1..tableSize do
            id=rem(Proj3.UFunctions.floatToInt(ownIdentity+:math.pow(2,i-1)),Proj3.UFunctions.floatToInt(:math.pow(2,tableSize)))
            findSuccessor(nodeIdentifierList,id)
        end
        fingerTablePID=[]
        chordState=[ownIdentity,predecessorID,predecessorPID,successorIDs,successorPIDs,fingerTable,fingerTablePID]
        IO.inspect(chordState)
        {:ok,chordState}
    end

    @doc """
        This function is used to set Predecessor and Successor PIDs of a node in Chord Ring.
    """

    def handle_cast({:setPreSuc},chordState) do
        predecessorPID=Proj3.CLI.whereis(Enum.at(chordState,1))
        successorNum = length(Enum.at(chordState, 3))-1
        successorPIDs = []
        successorPIDs = 
        for i <- 0..successorNum do
            Enum.at(chordState,3)
            |> Enum.at(i)
            |> Proj3.CLI.whereis()
        end
         
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),predecessorPID,Enum.at(chordState,3),successorPIDs,Enum.at(chordState,5),Enum.at(chordState,6)]  
        {:noreply,chordState}
    end 

    @doc """
        This function is used to print a node of Chord Ring.
    """

    def handle_call({:printState}, _from, chordState) do
        IO.inspect(chordState)
        {:reply, chordState, chordState}
    end

    @doc """
        This function is used to set PIDs of all node which are in Finger Table for a node.
    """
    
    def handle_cast({:setFT},chordState) do
        fingerTable=Enum.at(chordState,5)
        l3=length(fingerTable)
        fingerTablePID = for i <- 1..l3 do
            Proj3.CLI.whereis(Enum.at(fingerTable,i-1))
        end
        chordState=[Enum.at(chordState,0),Enum.at(chordState,1),Enum.at(chordState,2),Enum.at(chordState,3),Enum.at(chordState,4),Enum.at(chordState,5),fingerTablePID]
        {:noreply,chordState}
    end

    @doc """
        This function finds successor for a node.
    """
    def findSuccessor(nodeIdentifierList,id) do
        Proj3.UFunctions.search(nodeIdentifierList,id)
    end

    @doc """
        This function is used to log to the base 2 for a number.
    """
    def logCal(n) do
        r = Float.ceil(:math.log2(n) * 2)
        IO.inspect(r)
    end

    @doc """
        This function processes requests.
    """
    def handle_cast({:processRequest,numRequests,nodeIdentifierList,killedNodesIDList,tableSize}, chordState) do
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
            startRouting(randomNumber,currentNodeIndex,chordState,message,hopCount, tableSize, lastElement, firstElement,killedNodesIDList)
        end
        {:noreply, chordState}
    end

    def handle_cast({:forwardMessage, randomNumber, message, hopCount, tableSize, lastElement, firstElement,killedNodesIDList}, chordState) do
        currentNodeIndex=Enum.at(chordState,0)
        startRouting(randomNumber, currentNodeIndex, chordState,message, hopCount, tableSize, lastElement, firstElement,killedNodesIDList)
        {:noreply, chordState}
    end

    @doc """
        This function finds the successor when given a key.
    """
    def startRouting(randomNumber,currentNodeIndex,chordState,message,hopCount,tableSize,lastElement,firstElement,killedNodesIDList) do
        #message="Chord Protocol" <> " Initiator " <> Integer.to_string(Enum.at(chordState,0)) <> " Key " <> Integer.to_string(randomNumber)
        #Process.sleep(5000)
        #IO.inspect(message)
        successorList=Enum.at(chordState,3)
        successorOne=Enum.at(successorList,0)
        predecessorID=Enum.at(chordState,1)
        cond do
            currentNodeIndex==firstElement ->
                #generateList2(0,currentNodeIndex)
                if(randomNumber>=0 and randomNumber<=currentNodeIndex) do
                    IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                    IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                    announceHopCount(hopCount,message)
                else
                    if(Enum.member?(killedNodesIDList,successorOne)==false) do
                        if(randomNumber>currentNodeIndex and randomNumber<=successorOne) do
                            IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                            IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                            announceHopCount(hopCount+1,message)
                        else
                            forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)        
                        end        
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)
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
                    if(Enum.member?(killedNodesIDList,successorOne)==false) do
                        upperBound=Proj3.UFunctions.floatToInt(:math.pow(2,tableSize))
                        if((randomNumber>currentNodeIndex and randomNumber<upperBound) or (randomNumber>=0 and randomNumber<=successorOne)) do
                            IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                            IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                            announceHopCount(hopCount+1,message)
                        else
                            forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)        
                        end
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)
                    end
                                    
                end
                #generateList2(predecessorID+1,currentNodeIndex)
                
            true ->
                if(randomNumber>predecessorID and randomNumber<=currentNodeIndex) do
                    IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                    IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                    announceHopCount(hopCount,message)
                else
                    if(Enum.member?(killedNodesIDList,successorOne)==false) do
                        if(randomNumber>currentNodeIndex and randomNumber<=successorOne) do
                            IO.inspect("Key " <> Integer.to_string(randomNumber) <> " Found.")
                            IO.inspect("Hopcount for Key " <> Integer.to_string(randomNumber) <> " is " <> Integer.to_string(hopCount) <> ".")
                            announceHopCount(hopCount+1,message)
                        else
                            forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)        
                        end
                    else
                        forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement, firstElement,killedNodesIDList)
                    end
                end
                #generateList2(predecessorID+1,currentNodeIndex)
        end
        
    end

    @doc """
        This function sends the number of hops to the main process.
    """
    def announceHopCount(hopCount,_message) do
        send :hcReceiver, {:receiveHopCount, hopCount}
    end

    def forwardMessage(chordState,currentNodeIndex,randomNumber,message,hopCount, tableSize,lastElement,firstElement,killedNodesIDList) do
        #IO.inspect("Hopcount"<>Integer.to_string(hopCount))
        fingerTable=Enum.at(chordState,5)
        tempTable=Enum.reverse(fingerTable)
        startIndex=currentNodeIndex+1
        endIndex=randomNumber-1
        abc = cond do
            randomNumber<currentNodeIndex==true ->
                #generateList(startIndex,endIndex,tableSize)
                cpn2(tempTable,startIndex,endIndex,randomNumber, currentNodeIndex, chordState,tableSize,killedNodesIDList)
            randomNumber>currentNodeIndex==true ->
                #generateList2(startIndex,endIndex)
                cpn2(tempTable,startIndex,endIndex,randomNumber, currentNodeIndex, chordState,killedNodesIDList)
        end

        #IO.inspect(rangeList)
        #IO.inspect("for " <> Integer.to_string(currentNodeIndex))
        #IO.inspect(abc)
        abcPID=Proj3.CLI.whereis(abc)
        GenServer.cast(abcPID,{:forwardMessage, randomNumber, message, hopCount+1, tableSize, lastElement, firstElement, killedNodesIDList})
    end

    @doc """
        This function calculates closest preceding node 
    """
    def cpn2(fingerTable, startIndex, endIndex, key, currentNodeIndex, chordState, tableSize \\0, killedNodesIDList) do
        
        [head|tail]=fingerTable
        myNum = if(key<currentNodeIndex) do
            cond do 
                length(tail)==0 ->
                    successorList=Enum.at(chordState,3)
                    successorOne=Enum.at(successorList,0)
                (head>=startIndex and head<Proj3.UFunctions.floatToInt(:math.pow(2,tableSize))) or (head>=0 and head<=endIndex) ->
                    if(Enum.member?(killedNodesIDList,head)==false) do
                        head
                    else
                        findAmongSuccessor(Enum.at(chordState,3),killedNodesIDList)
                    end
                true ->
                    cpn2(tail,startIndex,endIndex,key,currentNodeIndex,chordState,tableSize,killedNodesIDList)
            end
        else
            cond do 
                length(tail)==0 ->
                    successorList=Enum.at(chordState,3)
                    successorOne=Enum.at(successorList,0)
                head>=startIndex and head<=endIndex ->
                    if(Enum.member?(killedNodesIDList,head)==false) do
                        head
                    else
                        findAmongSuccessor(Enum.at(chordState,3),killedNodesIDList)
                    end
                true ->
                    cpn2(tail,startIndex,endIndex,key,currentNodeIndex,chordState,killedNodesIDList)
            end
        end
        
        myNum 
    end

    @doc """
        This function is find whether the r successors are alive or not
    """
    def findAmongSuccessor(successorList,killedNodesIDList) do
        [head|tail]=successorList
        successor = cond do
            length(tail)==0 ->
                IO.inspect("All the r successors are killed. So the Chord Protocol won't work.")
                System.halt(0)
            true ->
                if(Enum.member?(killedNodesIDList,Enum.at(tail,0))==false) do
                    Enum.at(tail,0)
                else
                    findAmongSuccessor(tail,killedNodesIDList)
                end
        end
        
    end
end