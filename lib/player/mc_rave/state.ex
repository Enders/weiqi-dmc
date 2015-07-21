defmodule WeiqiDMC.Player.MCRave.State do
  defstruct n: HashDict.new,
            q: HashDict.new,
            n_tilde: HashDict.new,
            q_tilde: HashDict.new,
            tree: nil,
            simulations: 0
end