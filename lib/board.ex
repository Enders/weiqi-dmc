defmodule WeiqiDMC.Board do
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Helpers

  def from_full_board(full_board, size) do
    prep_board_data = full_board
      |> Enum.chunk(size)
      |> Enum.reverse
      |> Enum.with_index
      |> Enum.map(fn({row_data, row}) -> { Enum.with_index(row_data), row} end)

    from_full_board_row %State{ board: State.empty_board(size), size:  size }, prep_board_data
  end

  def from_full_board_row(state, []) do state end
  def from_full_board_row(state, [{row_data, row}|remaining]) do
    from_full_board_row from_full_board_column(state, row, row_data), remaining
  end

  def from_full_board_column(state, _, []) do state end
  def from_full_board_column(state, row, [{value, column}|remaining]) do
    cond do
       Enum.member?([:black, :b, "Black", "black", "B", "b"], value) ->
        {:ok, state} = compute_move(force_next_player(state, :black), {row+1, column+1})
       Enum.member?([:white, :w, "White", "white", "W", "w"], value) ->
        {:ok, state} = compute_move(force_next_player(state, :white), {row+1, column+1})
       true -> #
     end
      from_full_board_column state, row, remaining
  end

  def change_size(_, size) do
    cond do
      Enum.member?([9,13,19], size) ->
        %State{ board: State.empty_board(size), size:  size }
      true -> :ko
    end
  end

  def force_opposite_player(state) do
    %{ state | next_player: Helpers.opposite_color(state.next_player) }
  end

  def force_next_player(state, color) do
     %{ state | next_player: Helpers.normalize_color(color) }
  end

  def clear_board(state) do
    %State{ board: State.empty_board(state.size), size:  state.size }
  end

  def change_komi(state, komi) do
    %{ state | komi: komi }
  end

  def set_handicap(state, handicap) when handicap < 2 or handicap > 9 do
    {:ko, state}
  end

  def set_handicap(state, handicap) do
    handicap_coordinates = Helpers.handicap_coordinates(state.size, handicap) |> Enum.map(&Helpers.coordinate_string_to_tuple(&1))
    compute_moves state, handicap_coordinates, :black
  end

  def compute_moves(state, [], _) do
    {:ok, state}
  end

  def compute_moves(state, [coordinate|rest], color) do
    case compute_move((state |> force_next_player(color)), coordinate) do
      {:ok, state} -> compute_moves state, rest, color
      {:ko, _ }    -> {:ko, state }
    end
  end

  def compute_move(state, coordinate, color) do
    compute_move (state |> force_next_player(color)), coordinate
  end

  def compute_move(state, :pass) do
    {:ok,  %{state | board: remove_ko(state.board, state.coordinate_ko),
                     coordinate_ko: nil,
                     next_player: Helpers.opposite_color(state.next_player) } }
  end

  def compute_move(state, coordinate) do
    if State.board_value(state.board, coordinate) != :empty do
      {:ko, state}
    else
      compute_valid_move state, coordinate
    end
  end

  def compute_valid_move(state, coordinate) do
    color        = state.next_player
    surroundings = surroundings coordinate, state.size

    empty        = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == :empty end)

    other_player = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == Helpers.opposite_color(color) end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    same_player  = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == color end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    liberties_same_player_group = Enum.map(same_player, fn ({_, _, liberties}) ->
        length Enum.filter(liberties, fn (liberty) -> liberty != coordinate end)
      end) |> Enum.sum

    capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
      liberties == [coordinate]
    end)

    cond do
      liberties_same_player_group < 1 and length(empty) == 0 and length(capturing) == 0 ->
        {:ko, state}
      true ->
        {board, groups}           = process_move(state.board, state.groups, coordinate, color, empty)
        {board, groups, captured} = process_capture(board, groups, capturing, 0)

        board = remove_ko board, state.coordinate_ko

        if captured == 1 do
          possible_ko_coordinate = capturing |> List.first |> elem(1) |> List.first
          ko_surroundings = surroundings possible_ko_coordinate, state.size
          groups_around_ko_in_atari = groups |> Enum.filter(fn({_, coordinates, liberties}) ->
            length(coordinates) == 1 and liberties == [possible_ko_coordinate] and (ko_surroundings |> Enum.any?(fn(surrounding) ->
              Enum.member?(coordinates, surrounding)
            end))
          end)
          if length(groups_around_ko_in_atari) == 1 do
            coordinate_ko = possible_ko_coordinate
            board = State.update_board board, coordinate_ko, :ko
          end
        else
          coordinate_ko = nil
        end

        {:ok,  %{state | board: board,
                         groups: groups,
                         next_player: Helpers.opposite_color(color),
                         coordinate_ko: coordinate_ko,
                         captured_white: state.captured_white + (if color == :black do captured else 0 end),
                         captured_black: state.captured_black + (if color == :white do captured else 0 end) } }
    end
  end

  def remove_ko(board, nil) do board end
  def remove_ko(board, coordinate_ko) do
    State.update_board board, coordinate_ko, :empty
  end

  def group_containing(coordinate, groups) do
    Enum.find groups, fn ({_, coordinates, _}) ->
      Enum.member? coordinates, coordinate
    end
  end

  def process_move(board, groups, coordinate, color, move_liberties) do
    #Remove the move in the list of liberties for opposite color groups
    groups = groups |>
      Enum.map(fn ({group_color, coordinates, liberties}) ->
        if group_color == Helpers.opposite_color(color) and Enum.member?(liberties, coordinate) do
            {group_color, coordinates, liberties -- [coordinate]}
        else
          {group_color, coordinates, liberties }
        end
      end)

    #For same group color, find all the groups that have this move as liberty
    #and put them in a list to be merged.
    to_merge = groups |> Enum.filter(fn ({group_color, _, liberties}) ->
      group_color == color and Enum.member?(liberties, coordinate)
    end)

    if !Enum.empty?(to_merge) do
      coordinates = to_merge |> Enum.map(fn ({_, coordinates, _}) -> coordinates end)
                             |> List.flatten
                             |> Enum.uniq
      liberties   = to_merge |> Enum.map(fn ({_, _, liberties}) -> liberties end)
                             |> List.flatten
                             |> Enum.uniq

      merged = {color, [coordinate|coordinates], Enum.uniq((liberties ++ move_liberties) -- [coordinate])}
      groups = (groups -- to_merge) ++ [merged]
    else
      groups = groups ++ [{color, [coordinate], move_liberties}]
    end

    { State.update_board(board, coordinate, color), groups }
  end

  def process_capture(board, groups, [], captured) do
    {board, groups, captured}
  end

  def process_capture(board, groups, [{_, coordinates, _}|rest], captured) do
    {board, groups} = process_capture_group(board, groups, coordinates)
    process_capture board, groups, rest, captured + length(coordinates)
  end

  def process_capture_group(board, groups, []) do
    {board, groups}
  end

  def process_capture_group(board, groups, [capture|rest]) do
    #Remove all the groups containing the removed stone
    groups = groups |> Enum.reject(fn ({_, coordinates, _}) ->
      Enum.member?(coordinates, capture)
    end)

    surroundings = surroundings capture, State.board_size(board)

    #Add liberties to the surrounding groups
    groups = groups |> Enum.map(fn ({color, coordinates, liberties}) ->
      if coordinates -- surroundings != coordinates do
        {color, coordinates, Enum.uniq(liberties ++ [capture])}
      else
        {color, coordinates, liberties}
      end
    end)

    process_capture_group State.update_board(board, capture, :empty), groups, rest
  end

  def valid_move?(state, coordinate) do
    #TODO: make it way faster by not computing the new board
    {result, _} = compute_move(state, coordinate)
    result == :ok
  end


  def enclosed_regions(state, color, seed_coordinates) do
    opposite_color = Helpers.opposite_color color
    coordinates = seed_coordinates
      |> Enum.map(fn coordinate -> surroundings(coordinate, state.size) end)
      |> List.flatten
      |> Enum.filter(fn coordinate ->
        coordinate != :invalid and
        Enum.member?([:ko, :empty, opposite_color], State.board_value(state.board, coordinate))
      end)|> Enum.uniq

    enclosed_regions_rec state, color, coordinates, [], []
  end

  def enclosed_regions_rec(_, _, [], _, regions) do regions end
  def enclosed_regions_rec(state, color, [current|rest], visited, regions) do

    surroundings = current |> surroundings(state.size)
                           |> Enum.filter(fn (coordinate) -> coordinate != :invalid end)
                           |> Enum.map(fn (coordinate) -> {State.board_value(state.board, coordinate), coordinate} end)

    possible_surroundings = surroundings |> Enum.filter(fn {surrounding, _} -> surrounding != color end)
                                         |> Enum.map(fn {_, coordinate} -> coordinate end)

    {matching, non_matching} = regions |> Enum.partition(fn {coordinates, _} ->
      possible_surroundings |> Enum.any?(fn coordinate ->
        Enum.member?(coordinates, coordinate)
      end)
    end)

    liberty = Enum.member?([:empty, :ko], State.board_value(state.board, current))

    flat_match = matching |> List.flatten
    matching_coordinates = flat_match |> Enum.map(fn {coordinates, _} -> coordinates end) |> List.flatten |> Enum.uniq
    matching_liberties   = flat_match |> Enum.map(fn {_, liberties}   -> liberties   end) |> List.flatten |> Enum.uniq

    if liberty do
      regions = [{[current|matching_coordinates], [current|matching_liberties]}|non_matching]
    else
      regions = [{[current|matching_coordinates], matching_liberties}|non_matching]
    end

    enclosed_regions_rec state, color, (Enum.uniq(possible_surroundings++rest)--visited), [current|visited], regions
  end

  #The implementation below may be useful later but not sure for what yet :)
  #It groups all empty coordinates into regions through flood fill, and mark them as either
  #dame, black or white. It's not the same 'enclosed regions' in Benson's sense.

  #Also, it took a while to write this and get it to work so I don't want to delete it just yet.

  # def enclosed_regions(state) do
  #   enclosed_regions_rec state, State.empty_coordinates(state.board), []
  # end

  # def enclosed_regions_rec(_, [], regions) do regions end
  # def enclosed_regions_rec(state, [current|remaining], regions) do
  #   surroundings = current |> surroundings(state.size)
  #                          |> Enum.filter(fn (coordinate) -> coordinate != :invalid end)
  #                          |> Enum.map(fn (coordinate) -> {State.board_value(state.board, coordinate), coordinate} end)

  #   colors = surroundings  |> Enum.map(fn (surrounding) -> elem(surrounding, 0) end)
  #                          |> Enum.uniq

  #   {matching, non_matching} = regions |> Enum.partition(fn {_, coordinates} ->
  #     surroundings |> Enum.any?(fn {_, coordinate} ->
  #       Enum.member?(coordinates, coordinate)
  #     end)
  #   end)

  #   if length(matching) > 0 do
  #     matched_coordinates = matching |> Enum.map(fn({_, coordinates}) -> coordinates end)
  #                                    |> List.flatten
  #     matched_colors      = matching |> Enum.map(fn({color, _}) -> color end)
  #                                    |> List.flatten
  #                                    |> Enum.uniq

  #     cond do
  #       Enum.member?(matched_colors, :dame) or (Enum.member?(colors++matched_colors, :black) and Enum.member?(colors++matched_colors, :white)) ->
  #         enclosed_regions_rec state, remaining, [{:dame, [current|matched_coordinates]}|non_matching]
  #       true ->
  #         color = (matched_colors++colors) |> Enum.find(fn (color) -> color == :black or color == :white end)
  #         if !color do color = :empty end
  #         enclosed_regions_rec state, remaining, [{color, [current|matched_coordinates]}|non_matching]
  #     end
  #   else
  #     if (Enum.member?(colors, :black) and Enum.member?(colors, :white)) do
  #       enclosed_regions_rec state, remaining, [{:dame, [current]}|regions]
  #     else
  #       color = colors |> Enum.find(fn (color) -> color == :black or color == :white end)
  #       if !color do color = :empty end
  #       enclosed_regions_rec state, remaining, [{color, [current]}|regions]
  #     end
  #   end
  # end

  defp surroundings(coordinate, size) do
    [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.map(&compute_coordinate_from_delta(&1, coordinate, size))
      |> Enum.filter(fn (surrounding) -> surrounding != :invalid end)
  end

  defp compute_coordinate_from_delta({delta_row, delta_column}, {row, column}, size) do
    cond do
      row+delta_row < 1 or row+delta_row > size             -> :invalid
      column+delta_column < 1 or column+delta_column > size -> :invalid
      true -> {row+delta_row, column+delta_column}
    end
  end
end