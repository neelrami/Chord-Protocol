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
    if(length(myArg)!==3 ) do
      IO.puts("Please provide the command line arguments as follows: numNodes numRequests numKillNodes.")
      System.halt(0)
    else
      numNodes=Proj3.UFunctions.stringToInt(Enum.at(myArg,0))
      numRequests=Proj3.UFunctions.stringToInt(Enum.at(myArg,1))
      numKillNodes = Proj3.UFunctions.stringToInt(Enum.at(myArg, 2))
      cond do
        numNodes==0 ->
          IO.puts("Number of Nodes should be greater than 0.")
          System.halt(0)
        numRequests==0 ->
          IO.puts("Number of Requests should be greater than 0.")
          System.halt(0)
        numKillNodes>=numNodes ->
          IO.puts("Number of killed Nodes should be less than Number of Nodes")
          System.halt(0)
        true ->
          startProj3(numNodes,numRequests, numKillNodes)
      end
    end
  end
  
  @doc """
    The main program starts here.
  """
  def startProj3(numNodes,numRequests, numKillNodes) do
    Process.register(self(), :hcReceiver)
    Registry.start_link(keys: :unique, name: PIDStore)
    m=nearestPowerof2(numNodes)
    myOutput1=calNI(numNodes,[],m)
    tableSize=Enum.at(myOutput1,0)
    nodeIdentifierList=Enum.at(myOutput1,1)
    #Proj3.UFunctions.printOutput(newNodeIDList)
    Enum.map(1..numNodes, fn i -> startLink1(i,nodeIdentifierList,tableSize) end)
    setPreSuc(nodeIdentifierList)
    setFingerTable(nodeIdentifierList)
    printState(nodeIdentifierList)
    killedNodesList = failNodes(0, numKillNodes, numNodes, [])
    #IO.inspect(killedNodesList)
    killedNodesIDList = getID(nodeIdentifierList,killedNodesList,[])
    #IO.inspect(killedNodesIDList)

    sendRequests(nodeIdentifierList,killedNodesIDList,numRequests,tableSize)
    
    totalRequests=(numNodes-numKillNodes)*numRequests
    #IO.inspect(totalRequests)
    hops=receiveHopCount(totalRequests,0,0)
    averagehops=Enum.sum(hops)/totalRequests
    IO.inspect("--------------------- AVERAGE HOP COUNT ------------------------")
    IO.inspect(Proj3.UFunctions.floatToInt(Float.ceil(averagehops)))
  end
  
  @doc """
    The below 2 methods are for Registry lookups
  """
  def via_tuple(nodeIdentifier), do: {:via, Registry, {PIDStore, nodeIdentifier}}
  
  def whereis(nodeIdentifier) do
    case Registry.lookup(PIDStore, nodeIdentifier) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def getID(nodeIdentifierList,killedNodesList,abcList) do
    abcList = for i <-1..length(killedNodesList) do
      nodeID=Enum.at(nodeIdentifierList,Enum.at(killedNodesList,i-1)-1)
      abcList++nodeID
    end

    abcList

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
  
  @doc """
    GneServer Entry Point.
  """
  def startLink1(nodeIndex,nodeIdentifierList,tableSize) do
    {:ok, pid} = GenServer.start_link(Proj3.Chord,[nodeIndex,nodeIdentifierList,tableSize], name: via_tuple(Enum.at(nodeIdentifierList,nodeIndex-1)))
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
  
  @doc """
    Calls GenServer.cast to set PIDs of successor and predecessor.
  """
  def setPreSuc(nodeIdentifierList) do
    Enum.map(nodeIdentifierList, fn i -> 
      myPID=whereis(i)
      GenServer.cast(myPID,{:setPreSuc}) end
    )
  end
  
  @doc """
    Calls GenServer.cast to set PIDs of all nodes in Finger Table.
  """
  def setFingerTable(nodeIdentifierList) do
    Enum.map(nodeIdentifierList, fn i -> 
      myPID=whereis(i)
      GenServer.cast(myPID,{:setFT}) end
    )
  end
  
  @doc """
    Calls GenServer.call to print state of node.
  """
  def printState(nodeIdentifierList) do
    l2=length(nodeIdentifierList)
    Enum.each(1..l2, fn i -> 
      myPID=whereis(Enum.at(nodeIdentifierList,i-1))
      IO.inspect(myPID)
      GenServer.call(myPID,{:printState}, :infinity) end
    )
  end
  
  @doc """
    This function is used to fail certain number of nodes.
  """
  def failNodes(nodesFailed,nodesToFail,numNodes,randomNumList) do
    if(nodesFailed<nodesToFail) do
      randomNodeNumber=:rand.uniform(numNodes)
      if(Enum.member?(randomNumList,randomNodeNumber)==true) do
        failNodes(nodesFailed,nodesToFail,numNodes,randomNumList)
      else
        randomNumList=Enum.concat(randomNumList,[randomNodeNumber])
        failNodes(nodesFailed+1,nodesToFail,numNodes,randomNumList)
      end
      
    else
      randomNumList  
    end
  end

  @doc """
    This function is used to send requests.
  """
  def sendRequests(nodeIdentifierList,killedNodesIDList,numRequests,tableSize) do
    for i <- 1..length(nodeIdentifierList) do
      if(Enum.member?(killedNodesIDList,Enum.at(nodeIdentifierList,i-1))==true) do
        IO.puts("The node with ID "<>Integer.to_string(Enum.at(nodeIdentifierList,i-1)) <> " is dead. So no request will be sent.")
      else
        currentPID=whereis(Enum.at(nodeIdentifierList,i-1))
        #Process.sleep(1000)
        GenServer.cast(currentPID,{:processRequest,numRequests,nodeIdentifierList,killedNodesIDList,tableSize})
      end
    end
  end


  @doc """
    This function receives hops.
  """
  def receiveHopCount(totalRequests, _hopCountsReceived, hopCounts) do

    hopCounts = for i <- 1..totalRequests do
      receive do
        {:receiveHopCount, qwerty} ->
          #IO.inspect(qwerty)
          #IO.puts "HopCount Number is " <> Integer.to_string(hopCount)
          #IO.inspect(hopCounts+Enum.at(myOutput,0))
          hopCounts+qwerty   
      end
    end
    hopCounts
  end
end