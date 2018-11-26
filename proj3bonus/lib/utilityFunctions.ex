defmodule Proj3.UFunctions do
    
    @moduledoc """
        This module contains some Utility functions which are used frequently.
    """

    @doc """
        This function converts a string to an integer.
    """
    def stringToInt(myString) do
        String.to_integer(myString)
    end
    
    @doc """
        This function converts a float to an integer.
    """
    def floatToInt(myFloat) do
        Kernel.trunc(myFloat)
    end

    @doc """
        This function converts an integer to a string.
    """
    def intToString(myInt) do
        Integer.to_string(myInt)
    end

    @doc """
        This function prints the argument.
    """
    def printOutput(myVar) do
        IO.inspect(myVar)
    end

    @doc """
        These functions below are variants of Binary Search.
    """
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

    @doc """
        This functions calculates log to the base 2.
    """
    def logCal(n) do
        r = Float.ceil(:math.log(n) * 2)
        #IO.inspect(r)
    end
end