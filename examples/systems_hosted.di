extern func print_hex(x: int): void
extern func write(fd: int, x: str): int

func main(): int {
    var bytes = write(1, "systems io from di")
    print_hex(bytes)
    return 0
}
