defmodule WeiqiDMC.BoardTest do
  use ExUnit.Case
  use TestHelpers

  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  doctest WeiqiDMC.Board

  setup do
    {:ok, state: State.empty_board(9) }
  end

  test "allow to play on an empty board", %{state: state} do
    {:ok, state} = Board.compute_move state, prep_coor("A1"), "Black"
    assert State.board_value(state, "A1") == :black
  end

  test "it allows to play next to a stone as long as there are liberties", %{state: state} do
    {:ok, state} = Board.compute_move state, prep_coor("A2"), "White"
    assert State.board_value(state, "A2") == :white
  end

  test "it doesn't allow suicide", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B8", "B9"]), "Black"
    {result, _}  = Board.compute_move state, prep_coor("A9"), "White"
    assert result == :ko
  end

  test "but it allows damezumari", %{state: state} do
    {:ok, state} = Board.compute_moves state, prep_coor(["A8", "B8", "B9"]), "Black"
    {_, state}   = Board.compute_move state, prep_coor("A9"), "Black"
    assert State.board_value(state, "A9") == :black
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
    assert State.board_value(state, "B9") == :ko
    {result, _} = Board.compute_move state, prep_coor("B9"), "Black"
    assert result == :ko
    {result, state} = Board.compute_move state, prep_coor("A7"), "Black"
    assert result == :ok
    assert State.board_value(state, "B9") == :empty
  end

  test "it really handles ko rules (bugcase)", %{state: state} do
    state = play_moves state, [             "C9", "D9", "E9", "F9", "G9", "H9", "J9",
                                "A8", "B8", "C8", "D8", "E8", "F8", "G8", "H8", "J8",
                                "A7", "B7", "C7", "D7", "E7", "F7", "G7", "H7", "J7",
                                "A6", "B6", "C6", "D6", "E6", "F6", "G6", "H6", "J6",
                                "A5", "B5", "C5", "D5", "E5", "F5", "G5", "H5", "J5",
                                "A4", "B4", "C4", "D4", "E4", "F4", "G4", "H4", "J4",
                                "A3", "B3", "C3", "D3", "E3", "F3", "G3", "H3", "J3",
                                "A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "J2",
                                "A1", "B1", "C1", "D1", "E1", "F1", "G1", "H1", "J1" ], "Black"
    state = play_moves state, ["A9"], "White"
    state = play_moves state, ["B9"], "Black"

    assert State.board_value(state, "A9") == :empty
  end

  test "calculates regions" do
    state = Board.from_full_board [:w, :b, :e, :b, :e, :b, :w, :e, :e,
                                   :w, :b, :w, :e, :w, :b, :w, :e, :e,
                                   :w, :b, :b, :b, :b, :b, :w, :e, :e,
                                   :w, :w, :w, :w, :w, :w, :w, :e, :e,
                                   :e, :e, :e, :e, :b, :e, :e, :b, :b,
                                   :e, :w, :e, :e, :w, :w, :w, :w, :w,
                                   :e, :b, :e, :e, :w, :w, :e, :e, :e,
                                   :e, :e, :e, :e, :w, :w, :e, :w, :e,
                                   :w, :e, :e, :e, :w, :e, :e, :e, :e], 9

    {color, coordinates, _} = Board.group_containing {9, 6}, state.groups

    assert color == :black

    enclosed_regions = Board.enclosed_regions state, :black, coordinates

    assert length(enclosed_regions) == 2
  end

  #This is a test for the other enclosed_region implementation

  # test "calculates regions" do
  #   state = Board.from_full_board [:e, :b, :e, :b, :e, :b, :e, :e, :e,
  #                                  :b, :b, :b, :b, :e, :b, :e, :w, :e,
  #                                  :w, :w, :w, :e, :e, :b, :e, :e, :e,
  #                                  :e, :e, :w, :e, :e, :b, :e, :e, :e,
  #                                  :e, :e, :w, :w, :w, :b, :b, :b, :b,
  #                                  :e, :w, :e, :e, :w, :w, :w, :w, :w,
  #                                  :e, :b, :e, :e, :w, :w, :e, :e, :e,
  #                                  :e, :e, :e, :e, :w, :w, :e, :w, :e,
  #                                  :w, :e, :e, :e, :w, :e, :e, :e, :e], 9

  #   regions = Board.enclosed_regions(state)
  #   black_regions = Enum.filter(regions, fn {color, _}-> color == :black end)
  #   white_regions = Enum.filter(regions, fn {color, _}-> color == :white end)
  #   assert length(regions) == 6
  #   assert length(black_regions) == 3
  #   assert length(white_regions) == 2
  #   assert Enum.sum(Enum.map(black_regions, fn {_, coordinates} -> length(coordinates) end)) == 14
  #   assert Enum.sum(Enum.map(white_regions, fn {_, coordinates} -> length(coordinates) end)) == 27
  # end
end
