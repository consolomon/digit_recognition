def model1(input_grid: list[int]):

    weights = [2, 1, 2, 4, -4, 4, 2, -1, 2]
    bias = -5

    # Compute sum
    total = bias
    for i in range(9):
        total += input_grid[i] * weights[i]

    zero_percentage = (total + 9) / 20
    one_percentage = 1 - zero_percentage
    print(f"Total: {total}")
    print(f"One percentage: {one_percentage}, Zero percentage: {zero_percentage}")

    return [zero_percentage, one_percentage]
