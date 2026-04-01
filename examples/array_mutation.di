extern func print_int(x: int): void;

func main(): int {
    let nums: int[] = [3, 6, 9, 12];
    nums[1] = nums[1] + 10;
    print_int(nums[1]);
    return 0;
}
