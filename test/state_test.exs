defmodule WeiqiDMC.StateTest do
  use ExUnit.Case

  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Board.State

  test "#empty_board -> build a board HashDict" do
    state = State.empty_board(9)
    assert state.size == 9
    assert State.board_value(state, {9,9}) == :empty
  end

  test "#fill_board -> build a board HashDict and fill it with a specific value" do
    state = State.fill_board(9, :ko)
    assert state.size == 9
    assert State.board_value(state, {9,9}) == :ko
  end

  test "#board_value/update_board -> read/update from board" do
    state = State.empty_board(9) |> State.update_board({2,2}, :black)
    assert State.board_value(state, {2,2}) == :black
  end

  test "#to_list" do
    state = State.empty_board(9) |> State.update_board({2,2}, :black)
    list  = State.to_list(state)
    assert length(list) == 81
    {_, _, value} = Enum.at list, Enum.find_index(list, fn({row, column, _}) ->
      row == 2 and column == 2 end)
    assert value == :black
  end

  test "#empty_coordinates" do
    state = State.empty_board(9) |> State.update_board({2,2}, :black)
    list = State.empty_coordinates(state)
    assert length(list) == 80
  end
end