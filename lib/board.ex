defmodule WeiqiDMC.Board do

  def start_link do
    Agent.start_link fn -> %WeiqiDMC.Board.State{size: 19, board: empty_board(19)} end
  end

  #GTP API
  #--------

  #TODO: move into gtp_commands instead?

  def state(board_agent) do
    Agent.get(board_agent, &(&1))
  end

  def showboard(board_agent) do
    WeiqiDMC.Board.State.to_string Agent.get(board_agent, &(&1))
  end

  def clear_board(board_agent) do
    Agent.update board_agent, fn state -> %{state | board: empty_board(state.size), moves: [],
                                                    captured_black: 0, captured_white: 0 } end
  end

  def change_size(board_agent, size) do
    cond do
      Enum.member?([9,13,19], size) ->
        Agent.update board_agent, fn state -> %{state | size: size, board: empty_board(size), moves: [],
                                                        captured_black: 0, captured_white: 0  } end
      true -> :ko
    end
  end

  def generate_move(board_agent, color) do
    state = Agent.get(board_agent, &(&1))
    case WeiqiDMC.Player.generate_move(state, normalize_color(color)) do
      :resign -> "resign"
      :pass ->
        play_move(board_agent, "pass", color)
        "pass"
      index ->
        coordinate = index_to_coordinate(index, state.size)
        case play_move(board_agent, coordinate, color) do
          {:ok, _} -> coordinate
          {:ko, _} -> "resign"
        end
    end
  end

  def change_komi(board_agent, komi) do
    Agent.update board_agent, fn state -> %{state | komi: komi } end
  end

  def set_handicap(_, handicap) when handicap < 2 or handicap > 9 do
    :ko
  end

  def set_handicap(board_agent, handicap) do
    %WeiqiDMC.Board.State{size: size} = Agent.get(board_agent, &(&1))
    play_moves board_agent, handicap_coordinates(size, handicap), :black
  end

  def play_moves(board_agent, moves, color) do
    state = Agent.get(board_agent, &(&1))
    case compute_moves(state, moves, normalize_color(color)) do
      {:ok, state} -> Agent.update board_agent, fn _ -> state end
      {:ko, _ }    -> :ko
    end
  end

  def play_move(board_agent, "pass", color) do
    state = Agent.get(board_agent, &(&1))
    updated_state = %{state | moves: state.moves ++ [(color |> String.downcase |> String.first) <> " pass"]}
    Agent.update board_agent, fn _ -> updated_state end
    {:ok, updated_state}
  end

  def play_move(board_agent, coordinate, color) do
    state = Agent.get(board_agent, &(&1))
    case compute_move(state, coordinate, normalize_color(color)) do
      {:ok, state} ->
        Agent.update board_agent, fn _ -> state end
        {:ok, state}
      {:ko, _ }    -> {:ko, state}
    end
  end

  #Board API
  #---------

  def compute_moves(state, [], _) do
    {:ok, state}
  end

  def compute_moves(state, [coordinate|rest], color) do
    case compute_move(state, coordinate, color) do
      {:ok, state} -> compute_moves(state, rest, color)
      {:ko, _ }    -> {:ko, state }
    end
  end

  def compute_move(state, coordinate, color) do

    move_index = normalize_index(coordinate, state.size)

    surroundings = [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.map(&compute_index_from_delta(&1, move_index, state.size))
      |> Enum.filter(fn (index) -> index != :invalid end)

    empty        = surroundings |> Enum.filter(fn (index) -> Enum.at(state.board, index) == :empty end)

    other_player = surroundings |> Enum.filter(fn (index) -> Enum.at(state.board, index) == opposite_color(color) end)
                                |> Enum.map(&compute_group(&1, state))
                                |> Enum.uniq(fn ({group, _}) -> Enum.sort(group) end)

    same_player  = surroundings |> Enum.filter(fn (index) -> Enum.at(state.board, index) == color end)
                                |> Enum.map(&compute_group(&1, state))
                                |> Enum.uniq(fn ({group, _}) -> Enum.sort(group) end)

    liberties_same_player_group = Enum.map(same_player, fn ({_, liberties}) ->
        length Enum.filter(liberties, fn (liberty) -> liberty != move_index end)
      end) |> Enum.sum

    capturing = Enum.filter(other_player, fn({_, liberties}) ->
      liberties == [move_index]
    end)

    cond do
      liberties_same_player_group <= 1 and length(empty) == 0 and length(capturing) == 0 -> {:ko, state}
      true ->
        {board, captured} = process_capture(state.board, capturing, 0)

        board = board |> Enum.with_index |> Enum.map(fn {value, index} ->
          cond do
            index == move_index -> color
            value == :ko        -> :empty
            true                -> value
          end
        end)

        if captured == 1 do
          ko_coordinate = capturing |> List.first |> elem(0) |> List.first
          board = List.replace_at(board, ko_coordinate, :ko)
        end

        {:ok,  %{state | board: board,
                         moves: state.moves ++ [normalize_coordinate(coordinate, state.size)],
                         captured_white: state.captured_white + (if color == :black do captured else 0 end) ,
                         captured_black: state.captured_black + (if color == :white do captured else 0 end)  } }
    end


  end

  def compute_group(index, state) do
    compute_group_inc [index], [], state, {[], []}, Enum.at(state.board, index)
  end

  def compute_group_inc([], _, _, group, _) do
    group
  end

  def compute_group_inc([coordinate|rest], visited, state, {group, liberties}, color) do

    surroundings = [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.map(&compute_index_from_delta(&1, coordinate, state.size))
      |> Enum.filter(fn (index) ->
        if index == :invalid do
          false
        else
          value = WeiqiDMC.Board.State.board_value(state, index)
          (value == color or value == :empty or value == :ko) and !Enum.member?(visited, index)
        end
      end)

    case WeiqiDMC.Board.State.board_value(state, coordinate) do
      :empty -> compute_group_inc(rest, visited ++ [coordinate], state, {group, liberties++[coordinate]}, color)
      color  -> compute_group_inc(rest ++ surroundings, visited ++ [coordinate], state, {group++[coordinate], liberties}, color)
    end
  end

  defp compute_index_from_delta({delta_row, delta_column}, index, size) do
    row    = round Float.floor(index / size)
    column = rem index, size
    cond do
      row+delta_row < 0 or row+delta_row >= size             -> :invalid
      column+delta_column < 0 or column+delta_column >= size -> :invalid
      true -> row_column_to_index(row+delta_row, column+delta_column, size)
    end
  end

  def process_capture(board, [], captured) do
    {board, captured}
  end

  def process_capture(board, [{group, _}|rest], captured) do
    process_capture process_capture_group(board, group), rest, captured + length(group)
  end

  def process_capture_group(board, []) do
    board
  end

  def process_capture_group(board, [capture|rest]) do
    process_capture_group List.replace_at(board, capture, :empty), rest
  end

  #Utilities
  #---------

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

  def opposite_color(:black) do :white end
  def opposite_color(:white) do :black end

  def normalize_color(color) when is_bitstring(color) do
    case color |> String.downcase |> String.first do
      "b" -> :black
      "w" -> :white
    end
  end

  def normalize_color(color) when is_integer(color) do
    color
  end

  defp row_column_to_index(row, column, size) do
    row*size + column
  end

  def index_to_coordinate(index, size) do
    row    = round Float.floor(index / size)
    column = rem index, size
    "#{String.at("ABCDEFGHJKLMNOPQRSTUVWXYZ", column)}#{row+1}"
  end

  def coordinate_to_index(coordinate, size) do
    normalized_column = coordinate |> String.upcase |> String.to_char_list |> List.first
    row               = String.to_integer String.slice(coordinate, 1,String.length(coordinate)-1)
    column            = Enum.find_index 'ABCDEFGHJKLMNOPQRSTUVWXYZ', fn (column) -> column == normalized_column end
    (size-row) * size + column
  end

  def normalize_coordinate(coordinate, _) when is_bitstring(coordinate) do
    coordinate
  end

  def normalize_coordinate(coordinate, size) do
    index_to_coordinate coordinate, size
  end

  def normalize_index(index, size) when is_bitstring(index) do
    coordinate_to_index index, size
  end

  def normalize_index(index, _) do
    index
  end

  defp empty_board(size) do
    List.duplicate :empty, size*size
  end
end