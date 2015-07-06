defmodule WeiqiDMC.BoardTest do
  use ExUnit.Case

  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Board

  setup do
    {:ok, board_agent} = Board.start_link
    Board.change_size board_agent, 9
    {:ok, board_agent: board_agent}
  end

  test "allow to play on an empty board", %{board_agent: board_agent} do
    {:ok, state} = Board.play_move board_agent, "A1", "Black"
    assert State.board_value(state.board, "A1") == :black
  end

  test "it allows to play next to a stone as long as there are liberties", %{board_agent: board_agent} do
    Board.play_move board_agent, "A1", "Black"
    {:ok, state} = Board.play_move board_agent, "A2", "White"
    assert State.board_value(state.board, "A2") == :white
  end

  test "it doesn't allow suicide", %{board_agent: board_agent} do
    Board.play_moves board_agent, ["A8", "B8", "B9"], "Black"
    {result, _} = Board.play_move board_agent, "A9", "White"
    assert result == :ko
  end

  test "but it allows damezumari", %{board_agent: board_agent} do
    Board.play_moves board_agent, ["A8", "B8", "B9"], "Black"
    {_, state} = Board.play_move board_agent, "A9", "Black"
    assert State.board_value(state.board, "A9") == :black
  end

  test "but it allows capture", %{board_agent: board_agent} do
    Board.play_moves board_agent, ["A8", "B8", "B9"], "Black"
    Board.play_moves board_agent, ["A7", "B7", "C7", "C8", "C9"], "White"
    {result, state} = Board.play_move board_agent, "A9", "White"
    assert result == :ok
    assert state.captured_black == 3
  end

  test "it handles ko rules", %{board_agent: board_agent} do
    Board.play_moves board_agent, ["A8", "B9"], "Black"
    Board.play_moves board_agent, ["B8", "C9"], "White"
    {_, state} = Board.play_move board_agent, "A9", "White"
    assert state.captured_black == 1
    assert State.board_value(state.board, "B9") == :ko
    {result, _} = Board.play_move board_agent, "B9", "Black"
    assert result == :ko
    {result, state} = Board.play_move board_agent, "A7", "Black"
    assert result == :ok
    assert State.board_value(state.board, "B9") == :empty
  end
end
