defmodule WeiqiDMC.BoardTest do
  use ExUnit.Case
  use TestHelpers

  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Board

  setup do
    {:ok, state: %State{ board: State.empty_board(9), size:  9 } }
  end

  test "allow to play on an empty board", %{state: state} do
    {:ok, state} = Board.compute_move state, prep_coor("A1"), "Black"
    assert State.board_value(state.board, "A1") == :black
  end

  test "it allows to play next to a stone as long as there are liberties", %{state: state} do
    {:ok, state} = Board.compute_move state, prep_coor("A2"), "White"
    assert State.board_value(state.board, "A2") == :white
  end

  test "it doesn't allow suicide", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B8", "B9"]), "Black"
    {result, _}  = Board.compute_move state, prep_coor("A9"), "White"
    assert result == :ko
  end

  test "but it allows damezumari", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B8", "B9"]), "Black"
    {_, state}   = Board.compute_move state, prep_coor("A9"), "Black"
    assert State.board_value(state.board, "A9") == :black
  end

  test "but it allows capture", %{state: state} do
    {:ok, state}    = Board.compute_moves state, prep_coor(["A8", "B8", "B9"]), "Black"
    {:ok, state}    = Board.compute_moves state, prep_coor(["A7", "B7", "C7", "C8", "C9"]), "White"
    {result, state} = Board.compute_move  state, prep_coor("A9"), "White"
    assert result == :ok
    assert state.captured_black == 3
  end

  test "it handles ko rules", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B9"]), "Black"
    {:ok, state} = Board.compute_moves state, prep_coor(["B8", "C9"]), "White"
    {_, state}   = Board.compute_move  state, prep_coor("A9"), "White"
    assert state.captured_black == 1
    assert State.board_value(state.board, "B9") == :ko
    {result, _} = Board.compute_move state, prep_coor("B9"), "Black"
    assert result == :ko
    {result, state} = Board.compute_move state, prep_coor("A7"), "Black"
    assert result == :ok
    assert State.board_value(state.board, "B9") == :empty
  end
end
