defmodule WeiqiDMC.Profile.PlayMove do
  import ExProf.Macro

  alias WeiqiDMC.Player.MCRave
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  def run do
    state = State.empty_board(9) |> Board.force_next_player(:black)

    #Slow... like SUPER SLOW
    # :fprof.apply(&MCRave.generate_move/2, [state, 1])
    # :fprof.profile
    # :fprof.analyse [callers: true, sort: :own, totals: true, details: false]

    profile do
      MCRave.sim_default state, []
    end
  end
end

WeiqiDMC.Profile.PlayMove.run