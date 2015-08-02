defmodule WeiqiDMC.Player.MCRave.State do
  defstruct n: HashDict.new,
            q: HashDict.new,
            n_tilde: HashDict.new,
            q_tilde: HashDict.new,
            win_rate_count: 0,
            win_rate_average: 0,
            simulations: 0,
            dynamic_komi: 0,
            tree: nil
end