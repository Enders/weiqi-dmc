defmodule WeiqiDMC.Profile.IPS do
  def run do
    size  = 9
    board = Tuple.duplicate(:empty, size*size)
    Task.async(fn -> IO.puts "method_1: #{ips(&method_1/2, [board, size], 2)}/seconds" end) |> Task.await
    Task.async(fn -> IO.puts "method_2: #{ips(&method_2/2, [board, size], 2)}/seconds" end) |> Task.await
  end

  def ips(method, arguments, seconds) do
    ips(method, arguments, 0, seconds*1000000) / seconds
  end

  def ips(_, _, iterations, remaining_time) when remaining_time < 0 do iterations end
  def ips(method, arguments, iterations, remaining_time) do
    {elapsed_time, _} = :timer.tc method, arguments
    ips method, arguments, iterations+1, remaining_time - elapsed_time
  end

  def method_1(board, size) do
    (0..size*size-1)
      |> Enum.filter_map(&method_1_predicate(&1), &method_1_map(&1))
  end

  def method_1_predicate?(board, index) do elem(board, index) == :empty end
  def method_1_map(index) do {trunc(index/size)+1, rem(index, size)+1} end

  def method_2(board, size) do
    method_2 board, size, 0, size*size, []
  end

  def method_2(_, size, max_index, max_index, coordinates) do coordinates end

  def method_2(board, size, index, max_index, coordinates) do
    if elem(board, index) == :empty do
      coordinates = [{trunc(index/size)+1, rem(index, size)+1}|coordinates]
    end
    method_2 board, size, index+1, max_index, coordinates
  end
end

WeiqiDMC.Profile.IPS.run