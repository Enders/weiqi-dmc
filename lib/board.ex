defmodule WeiqiDMC.Board do

 @empty 0
 @black 1
 @white 2
 @ko    3

 defmodule WeiqiDMC.Board.State do
    defstruct size: 19,
              handicap: 0,
              komi: 6.5,
              captured_black: 0,
              captured_white: 0,
              moves: [],
              board: []
  end

  def start_link do
    Agent.start_link fn -> %WeiqiDMC.Board.State{size: 19, board: empty_board(19)} end
  end

  def clear_board(board) do
    Agent.update board, fn state -> %{state | board: empty_board(state.size), moves: [],
                                              captured_black: 0, captured_white: 0 } end
    ""
  end

  def change_size(board, size) do
    cond do
      Enum.member?([9,13,19], size) ->
        Agent.update board, fn state -> %{state | size: size, board: empty_board(size), moves: [],
                                                  captured_black: 0, captured_white: 0  } end
      true -> :ko
    end
  end

  def change_komi(board, komi) do
    Agent.update board, fn state -> %{state | komi: komi } end
  end

  def set_handicap(_, handicap) when handicap < 2 or handicap > 9 do
    :ko
  end

  def set_handicap(board, handicap) do
    %WeiqiDMC.Board.State{size: size} = Agent.get(board, &(&1))
    new_board = play_moves empty_board(size), size, handicap_coordinates(size, handicap), @black
    Agent.update board, fn state -> %{state | board: new_board, moves: [],
                                              captured_black: 0, captured_white: 0 } end
  end

  def play_move(board, "pass", color) do
    %WeiqiDMC.Board.State{moves: moves} = Agent.get(board, &(&1))
    Agent.update board, fn state -> %{state | moves: moves ++ [(color |> String.downcase |> String.first) <> " pass"]} end
  end

  def play_move(board, coordinate, color) do
    %WeiqiDMC.Board.State{board: board_array, size: size, moves: moves} = Agent.get(board, &(&1))
    case Enum.at(board_array, coordinate_to_index(coordinate, size)) do
      @empty ->
        value = case color |> String.downcase |> String.first do
          "b" -> @black
          "w" -> @white
        end
        new_board = play_moves board_array, size, [coordinate], value
        Agent.update board, fn state -> %{state | board: new_board, moves: moves ++ [coordinate]} end
      _ -> :ko
    end
  end

  defp play_moves(current_board, _, [], _) do
    current_board
  end

  defp play_moves(current_board, size, [move|rest], color) do
    play_moves List.replace_at(current_board, coordinate_to_index(move, size), color), size, rest, color
  end

  defp handicap_coordinates(size, handicap) do
    case {size, handicap} do
      {19, 2} -> ["D4", "Q16"]
      {19, 3} -> ["D4", "Q16", "D16"]
      {19, 4} -> ["D4", "Q16", "D16", "Q4"]
      {19, 5} -> ["D4", "Q16", "D16", "Q4", "K10"]
      {19, 6} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10"]
      {19, 7} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K10"]
      {19, 8} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K4", "K16"]
      {19, 9} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K4", "K16", "K10"]

      {13, 2} -> ["D4", "K10"]
      {13, 3} -> ["D4", "K10", "D10"]
      {13, 4} -> ["D4", "K10", "D10", "K4"]
      {13, 5} -> ["D4", "K10", "D10", "K4", "G7"]
      {13, 6} -> ["D4", "K10", "D10", "K4", "D7", "K7"]
      {13, 7} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G7"]
      {13, 8} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G10", "G4"]
      {13, 9} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G10", "G4", "G7"]

      { 9, 2} -> ["C3", "G7"]
      { 9, 3} -> ["C3", "G7", "C7"]
      { 9, 4} -> ["C3", "G7", "C7", "G3"]
      { 9, 5} -> ["C3", "G7", "C7", "G3", "E5"]
      { 9, 6} -> ["C3", "G7", "C7", "G3", "C5", "G5"]
      { 9, 7} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E5"]
      { 9, 8} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E7", "E3"]
      { 9, 9} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E7", "E3", "E5"]
    end
  end

  defp coordinate_to_index(coordinate, size) do
    normalized_column = coordinate |> String.upcase |> String.to_char_list |> List.first
    row               = String.to_integer String.slice(coordinate, 1,String.length(coordinate)-1)
    column            = Enum.find_index 'ABCDEFGHJKLMNOPQRSTUVWXYZ', fn (column) -> column == normalized_column end
    (size-row) * size + column
  end

  def to_string(board) do
    %WeiqiDMC.Board.State{board: board_array, size: size} = Agent.get(board, &(&1))
    first_row = "ABCDEFGHJKLMNOPQRSTUVWXYZ" |> String.slice(0,size)
                                            |> String.graphemes
                                            |> Enum.join(" ")

    "\n   " <> first_row <> "\n" <> (board_array |> Enum.chunk(size)
                                              |> Enum.with_index
                                              |> Enum.map(&row_to_string(&1, size))
                                              |> Enum.join("\n"))
  end

  defp row_to_string({row_data, row}, size) do
    row_data |> Enum.with_index |> Enum.map(fn ({value, column}) ->
      base_value = case value do
        @empty -> "."
        @black -> "X"
        @white -> "O"
        @ko    -> "#"
      end
      if column == 0 do
        base_value = String.rjust "#{size-row} #{base_value}", 4
      end
      base_value
    end) |> Enum.join " "
  end

  defp empty_board(size) do
    List.duplicate @empty, size*size
  end
end