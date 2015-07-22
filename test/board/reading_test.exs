defmodule WeiqiDMC.Board.ReadingTest do
  use ExUnit.Case
  use TestHelpers

  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Board.Reading
  alias WeiqiDMC.Board

  doctest WeiqiDMC.Board.Reading

  setup do
    {:ok, state: State.empty_board(9) }
  end

  test "#ruin_perfectly_good_eye? / detect actual eyes" do
    state = Board.from_full_board [:e, :w, :w, :b, :e,
                                   :w, :e, :w, :b, :b,
                                   :w, :w, :b, :b, :e,
                                   :b, :b, :b, :b, :b,
                                   :b, :b, :b, :b, :b], 5

    state = Board.force_next_player(state, :white)

    assert Reading.ruin_perfectly_good_eye?(state, {5, 1}) == true
  end

  test "#ruin_perfectly_good_eye? / but allow saving from atari (fake eye)" do
    state = Board.from_full_board [:e, :w, :w, :b, :e,
                                   :w, :e, :w, :b, :b,
                                   :w, :w, :b, :b, :e,
                                   :e, :w, :b, :b, :b,
                                   :w, :e, :b, :b, :b], 5

    state = Board.force_next_player(state, :white)

    assert Reading.ruin_perfectly_good_eye?(state, {2, 1}) == true

    state = Board.from_full_board [:e, :w, :w, :b, :e,
                                   :w, :e, :w, :b, :b,
                                   :w, :w, :b, :b, :e,
                                   :e, :w, :b, :b, :b,
                                   :w, :b, :b, :b, :b], 5

    state = Board.force_next_player(state, :white)

    assert Reading.ruin_perfectly_good_eye?(state, {2, 1}) == false
  end
end