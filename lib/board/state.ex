defmodule WeiqiDMC.Board.State do

  alias WeiqiDMC.Helpers

  defstruct size: 19,
            handicap: 0,
            komi: 6.5,
            captured_black: 0,
            captured_white: 0,
            moves: [],
            groups: [],
            coordinate_ko: nil,
            board: nil

  def to_list(board) do
    board
      |> Dict.to_list
      |> Enum.map(fn ({row, column_dict}) ->
        column_dict
          |> Dict.to_list
          |> Enum.map(fn ({column, value}) ->
            {row, column, value}
          end)
      end)
      |> List.flatten
  end

  def empty_coordinates(board) do
    board |> to_list
          |> Enum.filter(fn({_, _, value}) -> value == :empty end)
          |> Enum.map(fn({row, column, _}) -> {row, column} end)
  end

  def update_board(board, coordinate, value) when is_bitstring(coordinate) do
    update_board board, Helpers.coordinate_string_to_tuple(coordinate), value
  end

  def update_board(board, {row, column}, value) do
    Dict.put board, row, Dict.put(Dict.fetch!(board, row), column, value)
  end

  def board_value(board, coordinate) when is_bitstring(coordinate) do
    board_value board, Helpers.coordinate_string_to_tuple(coordinate)
  end

  def board_value(board, {row, column}) do
    Dict.fetch! Dict.fetch!(board, row), column
  end

  def empty_board(size) do
    build_row_dict HashDict.new, size, size, :empty
  end

  def fill_board(size, with) do
    build_row_dict HashDict.new, size, size, with
  end

  def build_row_dict(dict, 0, _, _) do dict end
  def build_row_dict(dict, row, size, fill_with) do
    build_row_dict Dict.put(dict, row, build_column_dict(HashDict.new, size, fill_with)), row - 1, size, fill_with
  end

  def build_column_dict(dict, 0, _) do dict end
  def build_column_dict(dict, column, fill_with) do
    build_column_dict Dict.put(dict, column, fill_with), column - 1, fill_with
  end

  def board_size(board) do
    Dict.size board
  end

  def to_string(state) do
    first_row = "ABCDEFGHJKLMNOPQRSTUVWXYZ" |> String.slice(0, state.size)
                                            |> String.graphemes
                                            |> Enum.join(" ")

    board = state.board |> to_list
                        |> Enum.sort(fn ({row_1, col_1, _}, {row_2, col_2, _}) ->
                             row_1 < row_2 or (row_1 == row_2 and col_1 < col_2)
                           end)
                        |> Enum.map(fn (x) -> elem(x,2) end)
                        |> Enum.chunk(state.size)
                        |> Enum.reverse
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