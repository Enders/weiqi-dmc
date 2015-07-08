

defmodule TestHelpers do

  defmacro __using__(_) do
    quote do
      import TestHelpers
    end
  end

  def play_moves(state, moves, color) do
    {:ok, state} = WeiqiDMC.Board.compute_moves state, prep_coor(moves), color
    state
  end

  def prep_coor(coordinates) when is_list(coordinates) do
    coordinates |> Enum.map(&WeiqiDMC.Helpers.coordinate_string_to_tuple(&1))
  end

  def prep_coor(coordinate) do
    WeiqiDMC.Helpers.coordinate_string_to_tuple coordinate
  end
end

ExUnit.start()