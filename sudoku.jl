# Solve Every Sudoku Puzzle

## Reimplementaion of Peter Norvig's Python version
## See http://norvig.com/sudoku.html

## Throughout this program we have:
##   r is a row,    e.g. 'A'
##   c is a column, e.g. '3'
##   s is a square, e.g. "A3"
##   d is a digit,  e.g. '9'
##   u is a unit,   e.g. ["A1","B1","C1","D1","E1","F1","G1","H1","I1"]
##   grid is a grid,e.g. 81 non-blank chars, e.g. starting with '.18...7...
##   poss_values is a dict of possible values, e.g. {"A1":"12349", "A2":"8", ...}

using Base.Test

function cross(A::String, B::String)
    ## Cross product of elements in A and elements in B.
    vec([join([a,b]) for a in A, b in B])
end    

const digits = "123456789"
const rows = "ABCDEFGHI"
const cols = digits
const squares = sort(cross(rows, cols))
const unitlist = [[cross(rows, string(c)) for c in cols],
                  [cross(string(r), cols) for r in rows],
                  vec([cross(rs, cs) for rs in ["ABC", "DEF", "GHI"],
                                         cs in ["123", "456", "789"]])]
const units = [s => filter(u->s in u, unitlist) for s in squares]
const peers = [s => setdiff(Set(vcat(units[s]...)),Set([s])) for s in squares]

################ Unit Tests ################

function test()
    ## A set of unit tests.
    @test length(squares) == 81
    @test length(unitlist) == 27
    @test all([length(units[s]) == 3 for s in squares]) == true
    @test all([length(peers[s]) == 20 for s in squares]) == true
    @test units["C2"] == Array[["A2", "B2", "C2", "D2", "E2", "F2", "G2", "H2", "I2"],
                           ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9"],
                           ["A1", "B1", "C1", "A2", "B2", "C2","A3", "B3", "C3"]]
    @test peers["C2"] == Set(["A2", "B2", "D2", "E2", "F2", "G2", "H2", "I2",
                               "C1", "C3", "C4", "C5", "C6", "C7", "C8", "C9",
                               "A1", "A3", "B1", "B3"])
    println("All tests pass.")
end

################ Parse a Grid ################

function parse_grid(grid::String)
    ## Convert grid to a dict of possible values, {square: digits}, or
    ## return False if a contradiction is detected.
    # To start, every square can be any digit; then assign values from the grid.
    poss_values = [s => digits for s in squares]
    for (s,d) in grid_values(grid)
        if (d in digits) && (assign(poss_values, s, d) == false)
            return false # (Fail if we can't assign d to square s.)
        end
    end
    return poss_values
end
        
function grid_values(grid::String)
    ## Convert grid into a dict of [square => char] with '0' or '.' for empties.
    chars = filter(c->(c in digits) | (c in "0."), grid)
    @test length(chars) == 81
    return zip(squares, chars)
end

################ Constraint Propagation ################

function assign(poss_values::Dict, s::String, d::Char)
    # Eliminate all the other values (except d) from poss_values[s] and propagate.
    # Return values, except return False if a contradiction is detected.
    other_values = replace(poss_values[s],d,"")
    if all(d2-> eliminate(poss_values, s, d2) != false, other_values)
        return poss_values
    else
        return false
    end
end
        
function eliminate(poss_values::Dict, s::String, d::Char)
    ## Eliminate d from poss_values[s]; propagate when values or places <= 2.
    ## Return poss_values, except return False if a contradiction is detected.
    if !(d in poss_values[s])
        return poss_values ## Already eliminated
    end
    poss_values[s] = replace(poss_values[s],d,"")
    # (1) If a square s is reduced to one value d2, then eliminate d2 from the peers.
    if length(poss_values[s]) == 0
        return false # Contradiction: removed last value
    elseif length(poss_values[s]) == 1
        d2 = poss_values[s][1]
        if any(s2->eliminate(poss_values, s2, d2) == false, peers[s])
            return false
        end
    end
    # (2) If a unit u is reduced to only one place for a value d, then put it there.
    for u in units[s]
        dplaces = filter(r->d in poss_values[r], u)
        if length(dplaces) == 0
            return false ## Contradiction: no place for this value
        elseif length(dplaces) == 1
            # d can only be in one place in unit; assign it there
            if assign(poss_values, dplaces[1], d) == false 
                return false
            end
        end
    end
    return poss_values
end

################ Display as 2-D grid ################

function center(vals::String, width::Int64)
    (n_pad, rem) = divrem(width - length(vals), 2)
    pad = " " ^ n_pad
    pad * vals * pad * " "^rem
end

function display(poss_values::Dict)
    ## Display these values as a 2-D grid.
    width = 1+maximum([length(poss_values[s]) for s in squares])
    line = join(fill("-"^(width*3),3),'+')
    for r in rows
        println(join([center(poss_values["$r$c"],width) * ((c in "36") ? "|" : "") for c in cols]))
        if r in "CF"
            println(line)
        end
     end
    println("")
end

################ Search ################

solve(grid) = df_search(parse_grid(grid))

function find_fewest(poss_values::Dict)
    min_poss = 10
    sel_square = ""
    for v in poss_values
        n_poss = length(v[2])
        if (n_poss > 1) && (n_poss < min_poss)
            min_poss = n_poss
            sel_square = v[1]
        end
    end
    return min_poss, sel_square
end

function df_search(poss_values)
    ## Using depth-first search and propagation, try all possible values.
    if poss_values == false 
        return false ## Failed earlier
    end
    if all(s->length(poss_values[s]) == 1, squares)
        return poss_values ## Solved!
    end

    ## Chose the unfilled square s with the fewest possibilities
    n,s = find_fewest(poss_values)        
    for d in poss_values[s]
        pv = df_search(assign(copy(poss_values), s, d))
        if pv != false
            return pv
        end
    end
    return false
end

################## Utilities ################







function from_file(filename::String, sep="\n")
    ## Parse a file into a list of strings, separated by sep.
    f = open(filename,"r")
    fstring = readall(f)
    close(f)
    return split(strip(fstring), sep)
end
        


################ System test ################





function solve_all(grids, name="", showif=0.0)
    ## Attempt to solve a sequence of grids. Report results.
    ## When showif is a number of seconds, display puzzles that take longer.
    ## When showif is None, don't display any puzzles.
   function time_solve(grid)
        tic()
        poss_values = solve(grid)
        t = toq() 
        ## Display puzzles that take long enough
        if (showif != None) && (t > showif)
            display(grid_values(grid))
            poss_values && display(values)
            @printf "(%.5f seconds)\n" t
        end
        return (t, solved(poss_values))
    end

    arr = [tup[idx] for tup in [time_solve(grid) for grid in grids], idx in [1,2]]       
    times, results = arr[:,1], arr[:,2]
    N = length(grids)
    if N > 1
        @printf "Solved %d of %d %s puzzles (avg %.5f secs (%d Hz), max %.5f secs).\n"  sum(results) N name sum(times)/N N/sum(times) maximum(times)
    end
end

function solved(poss_values)
    ## A puzzle is solved if each unit is a permutation of the digits 1 to 9.
    unitsolved(unit) = Set([poss_values[s] for s in unit]) == Set([string(d) for d in digits])
    return (poss_values != false) && all(unit->unitsolved(unit), unitlist)
end
 
function random_puzzle(N=17)
    ## Make a random puzzle with N or more assignments. Restart on contradictions.
    ## Note the resulting puzzle is not guaranteed to be solvable, but empirically
    ## about 99.8% of them are solvable. Some have multiple solutions.
    poss_values = [s => digits for s in squares]
    for s in shuffle(squares)
        (assign(poss_values, s, poss_values[s][rand(1:end)]) != false) || break
        ds = [poss_values[s] for s in filter(s->length(poss_values[s]) == 1,squares)]
        if length(ds) >= N && length(Set(ds)) >= 8
            return join([(length(poss_values[s])==1) ? poss_values[s] : '.' for s in squares])
        end
    end
    return random_puzzle(N) ## Give up and make a new puzzle
end
 
grid1  = "003020600900305001001806400008102900700000008006708200002609500800203009005010300"
grid2  = "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......"
hard1  = ".....6....59.....82....8....45........3........6..3.54...325..6.................."
rand1 = "..7.2....3...........9......4...2...8.......1.....6......1.74...2.8.9...5..2....."    


test()
solve_all(from_file("easy50.txt", "========"), "easy", None)
solve_all(from_file("top95.txt"), "hard", None)
solve_all(from_file("hardest.txt"), "hardest", None)
solve_all([random_puzzle() for _ in 1:99], "random", None)
