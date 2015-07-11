defmodule WeiqiDMC.Profile.PlayMove do
  import ExProf.Macro

  alias WeiqiDMC.Player.MCRave
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  def run do
    state = State.empty_board(9) |> Board.force_next_player(:black)
    :random.seed(:os.timestamp)

    #Slow... like SUPER SLOW
    :fprof.apply(&MCRave.sim_default/2, [state, []])
    :fprof.profile
    :fprof.analyse [dest: 'profile.out']

    # profile do
    #   MCRave.sim_default state, []
    # end
  end
end

WeiqiDMC.Profile.PlayMove.run