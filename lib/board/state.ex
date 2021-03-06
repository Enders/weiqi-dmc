defmodule WeiqiDMC.Board.State do

  alias WeiqiDMC.Helpers

  defstruct size: 19,
            handicap: 0,
            komi: 6.5,
            captured_black: 0,
            captured_white: 0,
            moves: 0,
            groups: [],
            next_player: :black,
            coordinate_ko: nil,
            last_move: nil,
            consecutive_pass: false,
            handicap: 0,
            board: nil

  def to_list(state) do
    state.board |> Tuple.to_list
                |> Enum.chunk(state.size)
                |> Enum.with_index
                |> Enum.map(fn {row_data, row} ->
                  row_data
                    |> Enum.with_index
                    |> Enum.map(fn {value, column} ->
                      {row+1, column+1, value}
                    end)
                end)
                |> List.flatten
  end

  def empty_coordinates(state) do
    empty_coordinates state.board, state.size, 0, state.size*state.size, []
  end

  def empty_coordinates(_, _, max_index, max_index, coordinates) do coordinates end
  def empty_coordinates(board, size, index, max_index, coordinates) do
    if elem(board, index) == :empty do
      coordinates = [{trunc(index/size)+1, rem(index, size)+1}|coordinates]
    end
    empty_coordinates board, size, index+1, max_index, coordinates
  end

  def update_board(state, coordinate, value) when is_bitstring(coordinate) do
    update_board state, Helpers.coordinate_string_to_tuple(coordinate), value
  end

  def update_board(state, {row, column}, value) do
    position = coordinate_to_index(state, {row, column})
    %{ state | board: (state.board |> Tuple.delete_at(position) |> Tuple.insert_at(position, value)) }
  end

  def board_has_value?(state, {row, column}, value) do
    elem(state.board, (row-1)*state.size+(column-1)) == value
  end

  def board_value(state, coordinate) when is_bitstring(coordinate) do
    board_value state, Helpers.coordinate_string_to_tuple(coordinate)
  end

  def board_value(state, {row, column}) do
    elem state.board, (row-1)*state.size+(column-1)
  end

  def empty_board(size) do
    %WeiqiDMC.Board.State{board: Tuple.duplicate(:empty, size*size), size: size}
  end

  def fill_board(size, with) do
    %WeiqiDMC.Board.State{board: Tuple.duplicate(with, size*size), size: size}
  end

  defp coordinate_to_index(state, {row, column}) do
    (row-1)*state.size+(column-1)
  end

  def to_string(state) do
    first_row = "ABCDEFGHJKLMNOPQRSTUVWXYZ" |> String.slice(0, state.size)
                                            |> String.graphemes
                                            |> Enum.join(" ")

    board = state |> to_list
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
      Next Player: #{state.next_player}
      Move: #{state.moves}
      Last Move: #{Helpers.coordinate_tuple_to_string(state.last_move)}
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