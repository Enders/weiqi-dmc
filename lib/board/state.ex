defmodule WeiqiDMC.Board.State do
  defstruct size: 19,
            handicap: 0,
            komi: 6.5,
            captured_black: 0,
            captured_white: 0,
            moves: [],
            board: []

  def update_board(state, coordinate, value) when is_integer(coordinate) do
    %{state | board: List.replace_at(state.board, coordinate, value)}
  end

  def update_board(state, coordinate, value) when is_bitstring(coordinate) do
    %{state | board: List.replace_at(state.board, WeiqiDMC.Board.coordinate_to_index(coordinate, state.size), value)}
  end

  def update_board(state, {row, column}, value) do
    %{state | board: List.replace_at(state.board, row*state.size + column, value)}
  end

  def board_value(state, coordinate) when is_integer(coordinate) do
    Enum.at state.board, coordinate
  end

  def board_value(state, coordinate) when is_bitstring(coordinate) do
    Enum.at state.board, WeiqiDMC.Board.coordinate_to_index(coordinate, state.size)
  end

  def board_value(state, {row, column}) do
    Enum.at state.board, row*state.size + column
  end

  def to_string(state) do
    first_row = "ABCDEFGHJKLMNOPQRSTUVWXYZ" |> String.slice(0, state.size)
                                            |> String.graphemes
                                            |> Enum.join(" ")

    board = state.board |> Enum.chunk(state.size)
                        |> Enum.with_index
                        |> Enum.map(&row_to_string(&1, state.size))
                        |> Enum.join("\n")

    """
      Move: #{length(state.moves)}
      Captured White: #{state.captured_white}
      Captured Black: #{state.captured_black}

    """ <> "   " <> first_row <> "\n" <> board <> "\n"
  end

  defp row_to_string({row_data, row}, size) do
    row_data |> Enum.with_index |> Enum.map(fn ({value, column}) ->
      base_value = case value do
        :empty -> "."
        :black -> "X"
        :white -> "O"
        :ko    -> "#"
      end
      if column == 0 do
        base_value = String.rjust "#{size-row} #{base_value}", 4
      end
      base_value
    end) |> Enum.join " "
  end
end