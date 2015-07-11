# WeiqiDMC

WeiqiDMC stands for *Weiqi Distributed Monte Carlo*, just a fancy temporary name because naming it *GoSomething* would have made matters confusing, wouldn't it?

As it stands, the project is just a pet-project made to test out the hypothesis that performance losses in Elixir (compared to C/C++, especially when it comes to memory management) can be offseted by the ease of writing distributed applications.

## Main features

Supported GTP (Go Text Protocol) commands:

`[:version, :name, :protocol_version, :list_commands, :quit,
                 :known_command, :boardsize, :clear_board, :komi, :fixed_handicap,
                 :play, :genmove, :showboard, :set_game]`

Current engine is a Random Player. It has no other purpose than test out the rest of the framework.

## Installation & running

**Installation**

For profiling, you'll need to run `mix deps.get`, there are no other dependencies ATM.

**With GTP front-end**

Many GTP front-end seem particularity finicky with the path to the binary, so I ended-up just writing a simple bash script (chmod +x) and use the path to that script:

    #!/bin/bash
    cd FULL_PATH/TO/PROJECT && MIX_ENV=prod FULL_PATH/TO/MIX/BINARY run -e "WeiqiDMC.start_gtp_server"`

I used *Quarry* to test it out. Don't forget to run `MIX_ENV=prod mix compile` first :)

**The tests**

Same as normal, just `mix test`

## Roadmap

- [ ] Implement MC + RAVE
  - [x] Copy the imperative algorithm from Sylvain Gelly's 2011 paper (MCTS and RAVE Estimation in Computer Go) with Qeven heuristic
  - [ ] Write tests to secure the implementation (WIP)
  - [ ] Tune it to get a basic level of strength on 9x9, say 5-10k, with fixed time settings
  - [ ] Write one of the better heuristic proposed by Sylvain
  - [ ] Tune it to get it to an intermediate level of strength on 9x9, 2k-1d
- [ ] Make it distributed by spawing Erlang processes to perform multiple simulation in parallel, then regroup to calculate the new Q, Qtilde, N and Ntilde
- [ ] Add time management
- [ ] Add pondering
- [ ] Devise a protocol for testing vs other engines
- [ ] Tune the engine
- [ ] Glory
- [ ] Resign from the project and start a fork to *make things right*

## Contributing

Please do!