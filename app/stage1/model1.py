def model1(input_grid: list[int]):

    # Recalibrated on 40 labelled 3x3 zeros and ones (closed, open and
    # rounded 0s; straight, flagged, slanted and thick 1s): the centre cell
    # is the strongest "1" signal, the edge midpoints form the "0" ring
    weights = [0, 4, 0, 2, -6, 2, 0, 4, 0]
    bias = -7

    # Compute sum
    total = bias
    for i in range(9):
        total += input_grid[i] * weights[i]

    # Linear scale anchored at the reference digits: the ring 0 sums to 5
    # (100 % zero), the centre-column 1 to -5 (0 % zero); clamped to [0, 1]
    zero_percentage = min(max((total + 5) / 10, 0), 1)
    one_percentage = 1 - zero_percentage
    print(f"Total: {total}")
    print(f"One percentage: {one_percentage}, Zero percentage: {zero_percentage}")

    return [zero_percentage, one_percentage]
