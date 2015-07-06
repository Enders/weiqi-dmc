defmodule WeiqiDMC.StateTest do
  use ExUnit.Case

  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Player

  test "#empty_board -> build a board HashDict" do
    board = State.empty_board(9)
    assert Dict.size(board) == 9
    assert Dict.size(Dict.fetch!(board, 1)) == 9
    assert Dict.fetch!(Dict.fetch!(board, 9), 9) == :empty
  end

  test "#fill_board -> build a board HashDict and fill it with a specific value" do
    board = State.fill_board(9, :test)
    assert Dict.size(board) == 9
    assert Dict.size(Dict.fetch!(board, 1)) == 9
    assert Dict.fetch!(Dict.fetch!(board, 9), 9) == :test
  end

  test "#board_value/update_board -> read/update from board" do
    board = State.empty_board(9) |> State.update_board({2,2}, :test)
    assert State.board_value(board, {2,2}) == :test
  end

  test "#to_list" do
    board = State.empty_board(9) |> State.update_board({2,2}, :test)
    list = State.to_list(board)
    assert length(list) == 81
    {_, _, value} = Enum.at list, Enum.find_index(list, fn({row, column, _}) ->
      row == 2 and column == 2 end)
    assert value == :test
  end

  test "#empty_coordinates" do
    board = State.empty_board(9) |> State.update_board({2,2}, :test)
    list = State.empty_coordinates(board)
    assert length(list) == 80
  end
end