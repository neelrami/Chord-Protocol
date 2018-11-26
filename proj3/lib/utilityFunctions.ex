defmodule Proj3.UFunctions do
    @moduledoc """
        This module contains some Utility functions which are used frequently.
    """
    def stringToInt(myString) do
        String.to_integer(myString)
    end
    
    def floatToInt(myFloat) do
        Kernel.trunc(myFloat)
    end

    def intToString(myInt) do
        Integer.to_string(myInt)
    end

    def printOutput(myVar) do
        IO.inspect(myVar)
    end

    def search(list, target) do
        search(list, target, 0, length(list) - 1)
    end
      
    def search(list, _target, low, high) when high < low do
        successorIndex=rem(high+1,length(list))
        Enum.at(list,successorIndex)
    end
      
    def search(list, target, low, high) do
        mid = floatToInt(div(low + high, 2))
        cond do
            target < Enum.at(list, mid)  -> search(list, target, low, mid-1)
            target > Enum.at(list, mid)  -> search(list, target, mid+1, high)
            target == Enum.at(list, mid) -> Enum.at(list,mid)            
        end
    end

    
    def bSearch(list, target) do
        bSearch(list, target, 0, length(list) - 1)
    end
    
    def bSearch(_list, _target, low, high) when high < low do
        -1
    end
    
    def bSearch(list, target, low, high) do
        mid = trunc(div(low + high, 2))
        cond do
          target < Enum.at(list, mid)  -> bSearch(list, target, low, mid - 1)
          target > Enum.at(list, mid)  -> bSearch(list, target, mid + 1, high)
          target == Enum.at(list, mid) -> mid
        end
    end
    
    def via_tuple(nodeIdentifier), do: {:via, Registry, {PIDStore, nodeIdentifier}}
  
    def whereis(nodeIdentifier) do
        case Registry.lookup(PIDStore, nodeIdentifier) do
            [{pid, _}] -> pid
            [] -> nil
        end
    end
end