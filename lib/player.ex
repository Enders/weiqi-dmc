defmodule WeiqiDMC.Player do

  alias WeiqiDMC.Board.State

  def generate_move(state, color) do
    valid_moves = generate_valid_moves state, color
    if Enum.empty?(valid_moves) do
      :pass
    else
      :random.seed(:os.timestamp)
      Enum.at valid_moves, :random.uniform(length(valid_moves)) - 1
    end
  end

  def generate_valid_moves(state, color) do
    state.board
      |> State.empty_coordinates
      |> Enum.filter(fn coordinate -> valid_move?(coordinate, color, state) end)
  end

  def valid_move?(coordinate, color, state) do
    {result, _} = WeiqiDMC.Board.compute_move(state, coordinate, color)
    result == :ok
  end
end