defmodule WeiqiDMC.Player do
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
      |> Enum.with_index
      |> Enum.filter(fn {value, index} -> value == :empty end)
      |> Enum.filter(fn {_, index} -> valid_move?(index, color, state) end)
      |> Enum.map(fn {_, index} -> index end)
  end

  def valid_move?(index, color, state) do
    {result, _} = WeiqiDMC.Board.compute_move(state, index, color)
    result == :ok
  end
end