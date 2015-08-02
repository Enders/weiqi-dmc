defmodule WeiqiDMC.Board.Outcome do

  alias WeiqiDMC.Board.State
  import WeiqiDMC.Helpers, only: [surroundings: 2, opposite_color: 1]

  def outcome?(state, dynamic_komi \\ 0) do
    if black_wins?(state, dynamic_komi) do 1 else 0 end
  end

  def black_wins?(state, dynamic_komi) do
    black_points = count_stones(state, :black)
    white_points = count_stones(state, :white) + state.komi + dynamic_komi
    black_points - white_points > 0
  end

  #TODO: useful?

  # def dynamic_komi(state, value) do
  #   if state.moves < 20 do
  #     state.handicap * 7 * ( 1 - state.moves / 20 )
  #   else
  #     value
  #   end
  # end

  def count_stones(state, color) do
    state.groups
      |> Enum.map(fn({value, coordinates, _}) -> (value == color and coordinates) || HashSet.new end)
      |> Enum.reduce(HashSet.new, fn (coordinates, acc) -> Set.union(acc, coordinates) end)
      |> Set.size
  end

  def game_over?(state) do
    state.consecutive_pass
  end

  def benson_game_over?(state) do
    length(state.groups) > 0 and benson_everything_alive?(state, state.groups)
  end

  #http://webdocs.cs.ualberta.ca/~games/go/seminar/2002/020717/benson.pdf
  #http://senseis.xmp.net/?BensonsAlgorithm
  def benson_everything_alive?(_, []) do true end
  def benson_everything_alive?(state, [{color, coordinates, liberties}|groups]) do
    Set.size(liberties) > 1 and
    length(benson_vital_regions(state, {color, coordinates, liberties})) >= 2 and
    benson_everything_alive?(state, groups)
  end

  def benson_vital_regions(state, {color, coordinates, liberties}) do
    enclosed_regions(state, color, coordinates)
      |> Enum.filter(fn {_, empty_coordinates} ->
        Enum.all?(empty_coordinates, fn (empty_coordinate) ->
          Enum.member? liberties, empty_coordinate
        end)
      end)
  end

  def enclosed_regions(state, color, seed_coordinates) do
    opposite_color = opposite_color color
    coordinates = seed_coordinates
      |> Enum.map(fn coordinate -> surroundings(coordinate, state.size) end)
      |> List.flatten
      |> Enum.filter(fn coordinate ->
        coordinate != :invalid and
        Enum.member?([:ko, :empty, opposite_color], State.board_value(state, coordinate))
      end)|> Enum.uniq

    enclosed_regions_rec state, color, coordinates, [], []
  end

  def enclosed_regions_rec(_, _, [], _, regions) do regions end
  def enclosed_regions_rec(state, color, [current|rest], visited, regions) do

    surroundings = current |> surroundings(state.size)
                           |> Enum.filter(fn (coordinate) -> coordinate != :invalid end)
                           |> Enum.map(fn (coordinate) -> {State.board_value(state, coordinate), coordinate} end)

    possible_surroundings = surroundings |> Enum.filter(fn {surrounding, _} -> surrounding != color end)
                                         |> Enum.map(fn {_, coordinate} -> coordinate end)

    {matching, non_matching} = regions |> Enum.partition(fn {coordinates, _} ->
      possible_surroundings |> Enum.any?(fn coordinate ->
        Enum.member?(coordinates, coordinate)
      end)
    end)

    liberty = Enum.member?([:empty, :ko], State.board_value(state, current))

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
end