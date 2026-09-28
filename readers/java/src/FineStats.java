/**
 * §24.6: a GPU tile keeps its blocks in fast memory that holds STACK_DEPTH
 * blocks, the tile's own included; fine_tile adds 1 to spills for every
 * push made when the stack is already full, and 1 to tiles for every tile
 * it runs.
 */
public final class FineStats {
    public int spills = 0;
    public int tiles = 0;
}
