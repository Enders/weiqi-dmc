defmodule WeiqiDMC.Player.Random do
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Board

  def generate_move(state) do
    legal_moves = legal_moves state
    if Enum.empty?(legal_moves) do
      :pass
    else
      :random.seed(:os.timestamp)
      Enum.at legal_moves, :random.uniform(length(legal_moves)) - 1
    end
  end

  def legal_moves(state) do
    state
      |> State.empty_coordinates
      |> Enum.filter(fn coordinate -> Board.valid_move?(state, coordinate) end)
  end
end