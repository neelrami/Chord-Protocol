defmodule Proj3.CLI do
  
  @moduledoc """
    This module contains some methods which are used to intialize nodes in Chord Ring and also make request. 
  """
  def main(args \\ []) do
    args
    |> parse_args
    |> processInput
  end

  defp parse_args(args) do
    {_, myArg, _} =
      OptionParser.parse(args,strict: [:string])
      myArg
  end

  @doc """
    Entry point of the program.
  """
  defp processInput(myArg) do
    if(length(myArg)!==2 ) do
      IO.puts("Please provide the command line arguments as follows: numNodes numRequests.")
      System.halt(0)
    else
      numNodes=Proj3.UFunctions.stringToInt(Enum.at(myArg,0))
      numRequests=Proj3.UFunctions.stringToInt(Enum.at(myArg,1))
      cond do
        numNodes==0 ->
          IO.puts("Number of Nodes should be greater than 0.")
          System.halt(0)
        numRequests==0 ->
          IO.puts("NUmber of Requests should be greater than 0.")
          System.halt(0)
        true ->
          startProj3(numNodes,numRequests)
      end
    end
  end

  @doc """
    The main program starts here.
  """
  def startProj3(numNodes,numRequests) do
    Process.register(self(), :hcReceiver)
    #IO.inspect(Process.register(self(), :hcReceiver))
    Registry.start_link(keys: :unique, name: PIDStore)

    m=nearestPowerof2(numNodes)
    myOutput1=calNI(numNodes,[],m)

    
    tableSize=Enum.at(myOutput1,0)
    nodeIdentifierList=Enum.at(myOutput1,1)
    [listHead|listTail]=nodeIdentifierList
    lastNode=Enum.at(listTail,length(listTail)-1)
    #IO.inspect("LastNode")
    #IO.inspect(lastNode)
    listTail1=listTail -- [lastNode]
    #IO.inspect(listTail1)
    myList1=removeOneNode(listTail1)
    removedNodeID=Enum.at(myList1,0)
    #IO.inspect(nodeIdentifierList)
    newNodeIDList=Enum.at(myList1,1)
    myNodeIDList=[listHead] ++ newNodeIDList ++ [lastNode]
    
    #Proj3.UFunctions.printOutput(myNodeIDList)
    
    createChordRing(numNodes,myNodeIDList,tableSize)
    joinChordRing(removedNodeID,myNodeIDList,tableSize,listHead)
    stabilize(removedNodeID)
    
    pNode=Proj3.UFunctions.search(myNodeIDList,removedNodeID)
    pNodeIndex=Proj3.UFunctions.bSearch(myNodeIDList,pNode)
    pNode1=Enum.at(myNodeIDList,pNodeIndex-1)
    #Process.sleep(5000)
    GenServer.call(Proj3.UFunctions.whereis(Enum.at(myNodeIDList,pNodeIndex)),{:printState})

    stabilize(pNode1)

    pNode1PID=Proj3.UFunctions.whereis(pNode1)
    #Process.sleep(5000)
    GenServer.call(pNode1PID,{:printState})
    
    GenServer.call(Proj3.UFunctions.whereis(removedNodeID),{:printState})

    fixFingerTables(nodeIdentifierList,tableSize)
    IO.puts("Node with ID " <> Integer.to_string(removedNodeID) <> " has joined the Chord Ring.")
    IO.puts("Finger Tables fixed")

    Process.sleep(5000)

    for i <- 1..length(nodeIdentifierList) do
      GenServer.call(Proj3.UFunctions.whereis(Enum.at(nodeIdentifierList,i-1)),{:printState}, :infinity)
    end
    
    sendRequests(nodeIdentifierList,numRequests, tableSize)
    
    totalRequests=numNodes*numRequests
    hops=receiveHopCount(totalRequests,0,0)
    #Process.sleep(5000)
    #IO.inspect(hops)
    averagehops=Enum.sum(hops)/totalRequests
    #IO.inspect(hops)
    IO.inspect("---------------------  AVERAGE HOP COUNTS  --------------------------")
    IO.inspect(Proj3.UFunctions.floatToInt(Float.ceil(averagehops)))
  end

  @doc """
    This function creates Chord Ring of n-1 nodes.
  """
  def createChordRing(numNodes,newNodeIDList,tableSize) do
    Enum.map(1..numNodes-1, fn i -> startLink1(i,newNodeIDList,tableSize,0) end)
    setPreSuc(newNodeIDList)
    setFingerTable(newNodeIDList)
    #printState(newNodeIDList)
  end

  @doc """
    This function implements the network join functionality.
  """
  def joinChordRing(removedNodeID,newNodeIDList,tableSize,randomNode) do
    GenServer.start_link(Proj3.Chord,[removedNodeID,[],tableSize,1], name: Proj3.UFunctions.via_tuple(removedNodeID))
    removedNodePID=Proj3.UFunctions.whereis(removedNodeID)
    randomPID=Proj3.UFunctions.whereis(randomNode)
    GenServer.call(randomPID,{:findSuccessor,removedNodeID,removedNodePID},:infinity)
    #Process.sleep(10000)
    #GenServer.call(removedNodePID,{:printState})
    
  end

  @doc """
    This function implements the stabilize procedure.
  """
  def stabilize(removedNodeID) do
    removedNodePID=Proj3.UFunctions.whereis(removedNodeID)
    GenServer.cast(removedNodePID,{:stabilize})
  end

  @doc """
    This function fixes the Finger Tables.
  """
  def fixFingerTables(myList,tableSize) do
    for i <- 1..length(myList) do
      currentNode=Enum.at(myList,i-1)
      fingerTable = for i <- 1..tableSize do
        id=rem(Proj3.UFunctions.floatToInt(currentNode+:math.pow(2,i-1)),Proj3.UFunctions.floatToInt(:math.pow(2,tableSize)))
        Proj3.Chord.fingerTableConstruction(myList,id)
      end
      #IO.inspect(fingerTable)
      GenServer.cast(Proj3.UFunctions.whereis(currentNode),{:fixFT, fingerTable})
    end  
  end

  @doc """
    Used to calcuate value of m i.e Table Size
  """
  def nearestPowerof2(numNodes) do
    valM=:math.log2(numNodes) |> Float.ceil |> Proj3.UFunctions.floatToInt
    if(rem(valM,4)==0) do
      div(valM,4)
    else
      div(valM,4)+1
    end
  end

  @doc """
    This function calculates hash of each node using Consistent Hashing.
  """
  def calculateHash(nodeIndex,m) do
    newNodeIndex=Proj3.UFunctions.intToString(nodeIndex)
    :crypto.hash(:sha,newNodeIndex) |> Base.encode16 |> String.slice(0..m-1) |> String.to_integer(16)
  end

  def calculateHash2(myString,m) do
    :crypto.hash(:sha,myString) |> Base.encode16 |> String.slice(0..m-1) |> String.to_integer(16)
  end

  @doc """
    GneServer Entry Point.
  """
  def startLink1(nodeIndex,nodeIdentifierList,tableSize,flag) do
    {:ok, _pid} = GenServer.start_link(Proj3.Chord,[nodeIndex,nodeIdentifierList,tableSize,flag], name: Proj3.UFunctions.via_tuple(Enum.at(nodeIdentifierList,nodeIndex-1)))
  end

  def calNI(numNodes,niList,m) do
    niList = for i <- 1..numNodes do
      niList ++ calculateHash(i,m)
    end
    #IO.inspect(Enum.sort(niList))
    flag=Enum.at(uniqueCheck(niList,m),1)
    if(flag==true) do
      tableSize=m*4
      [tableSize,Enum.sort(niList)]
    else
      calNI(numNodes,[],m+1)
    end  
  end

  def calNI2(myStringList,aList,m) do
    _aList = for i <- 1..length(myStringList) do
      aList ++ calculateHash2(Enum.at(myStringList,i-1),m)
    end
  end

  @doc """
    This function is used to check whether the number is unique among a list of numbers.
  """
  def uniqueCheck(niList,m) do
    newList=Enum.uniq(niList)
    if(length(newList)===length(niList)) do
      [m,true]
    else
      [m,false]
    end
  end
  
  @doc """
    Calls GenServer.cast to set PIDs of successor and predecessor.
  """
  def setPreSuc(nodeIdentifierList) do
    Enum.map(nodeIdentifierList, fn i -> 
      myPID=Proj3.UFunctions.whereis(i)
      GenServer.cast(myPID,{:setPreSuc}) end
    )
  end

  @doc """
    Calls GenServer.cast to set PIDs of all nodes in Finger Table.
  """
  def setFingerTable(nodeIdentifierList) do
    Enum.map(nodeIdentifierList, fn i -> 
      myPID=Proj3.UFunctions.whereis(i)
      GenServer.cast(myPID,{:setFT}) end
    )
  end

  @doc """
    Calls GenServer.call to print state of node.
  """
  def printState(nodeIdentifierList) do
    l2=length(nodeIdentifierList)
    Enum.each(1..l2, fn i -> 
      myPID=Proj3.UFunctions.whereis(Enum.at(nodeIdentifierList,i-1))
      #IO.inspect(myPID)
      GenServer.call(myPID,{:printState}) end
    )
  end

  @doc """
    This function is used to remove a node.
  """
  def removeOneNode(nodeIdentifierList) do
    l4=length(nodeIdentifierList)
    randomNodeNumber=:rand.uniform(l4)
    randomNodeID=Enum.at(nodeIdentifierList,randomNodeNumber-1)
    #IO.inspect(randomNodeID)
    [randomNodeID,List.delete(nodeIdentifierList,randomNodeID)]
  end

  def selectRandomNode(nodeList) do
    l6=length(nodeList)-1
    randomNumber=:rand.uniform(l6)
    Enum.at(nodeList,randomNumber)
  end

  @doc """
    This function is used to send requests.
  """
  def sendRequests(nodeIdentifierList,numRequests, tableSize) do
    for i <- 1..length(nodeIdentifierList) do
      currentPID=Proj3.UFunctions.whereis(Enum.at(nodeIdentifierList,i-1))
      #Process.sleep(1000)
      GenServer.cast(currentPID,{:processRequest,numRequests,nodeIdentifierList, tableSize})
    end
  end

  @doc """
    This function receives hops.
  """
  def receiveHopCount(totalRequests, _hopCountsReceived, hopCounts) do

    hopCounts = for _i <- 1..totalRequests do
      receive do
        {:receiveHopCount, qwerty} ->
          #IO.inspect(myOutput)
          #IO.puts "HopCount Number is " <> Integer.to_string(hopCount)
          #IO.inspect(hopCounts+Enum.at(myOutput,0))
          hopCounts+qwerty   
      end
    end
    hopCounts
  end

end