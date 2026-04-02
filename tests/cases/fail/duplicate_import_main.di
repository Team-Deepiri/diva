package duplicate_demo

import "duplicate_import_a.di";
import "duplicate_import_b.di";

func main(): int {
    return clash();
}
