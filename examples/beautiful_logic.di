extern func print_int(x: int): void
extern func print_str(x: str): void

func abs(x: int): int {
    if x < 0 {
        return 0 - x
    } else {
        return x
    }
}

func max(a: int, b: int): int {
    if a >= b {
        return a
    } else {
        return b
    }
}

func min(a: int, b: int): int {
    if a <= b {
        return a
    } else {
        return b
    }
}

func clamp(x: int, low: int, high: int): int {
    return min(max(x, low), high)
}

func pulse(seed: int, step: int): int {
    var wave = seed * (step + 3) - step * step

    if wave < 0 {
        wave = abs(wave) + step * 7
    } else {
        if wave > 120 {
            wave = 120 - (wave - 120)
        } else {
            wave = wave + step
        }
    }

    return wave
}

func balance(left: int, right: int, bias: int): int {
    var delta = left - right
    var energy = abs(delta) + bias

    if delta > 0 {
        return energy + left / 2
    } else {
        if delta < 0 {
            return energy + right / 2
        } else {
            return energy + bias * 2
        }
    }
}

func shape_signal(values: int[], seed: int): int {
    var total = seed
    var i = 0

    while i < 8 {
        var current = values[i]
        var wave = pulse(seed + total, i + 1)

        if current > wave {
            total = total + balance(current, wave, i + 2)
        } else {
            total = total - balance(wave, current, i + 1) / 2
        }

        if i == 2 {
            total = total + current * (i + 1)
        } else {
            if i == 5 {
                total = total + current * (i + 1)
            } else {
                if current < 0 {
                    total = total + abs(current)
                } else {
                    total = total + current / (i + 1)
                }
            }
        }

        total = clamp(total, -500, 500)
        i = i + 1
    }

    return total
}

func weave_paths(a: int[], b: int[]): int {
    var score = 0
    var i = 0

    while i < 8 {
        var left = a[i]
        var right = b[7 - i]
        var mixed = balance(left, right, i + 3)

        if mixed > 40 {
            score = score + mixed
        } else {
            score = score + mixed * 2
        }

        if left > right {
            if left > 0 {
                score = score + left * (i + 1)
            } else {
                score = score + abs(left - right)
            }
        } else {
            if right > left {
                if right > 0 {
                    score = score + right * (8 - i)
                } else {
                    score = score + abs(left - right)
                }
            } else {
                score = score + abs(left - right)
            }
        }

        i = i + 1
    }

    return score
}

func final_orbit(base: int, echo: int, drift: int): int {
    var value = base + echo - drift
    var turn = 0

    while turn < 6 {
        if turn == 0 {
            value = value + 11
        } else {
            if turn == 1 {
                value = value * 2 - 9
            } else {
                if turn == 2 {
                    value = value + drift / 3
                } else {
                    if turn == 3 {
                        value = value - echo / 4
                    } else {
                        if turn == 4 {
                            value = value + abs(base - drift)
                        } else {
                            value = value + turn * 13 - 7
                        }
                    }
                }
            }
        }

        value = clamp(value, -2000, 2000)
        turn = turn + 1
    }

    return value
}

func main(): int {
    var skyline :: int[] = [5, 12, -3, 18, 7, 25, -9, 14]
    var river :: int[] = [8, -4, 11, 6, 19, -2, 13, 3]

    var shaped = shape_signal(skyline, 17)
    var woven = weave_paths(skyline, river)
    var orbit = final_orbit(shaped, woven, shape_signal(river, 9))

    print_str("di can do poetry with control flow")
    print_int(shaped)
    print_int(woven)
    print_int(orbit)
    return 0
}
