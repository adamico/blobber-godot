class_name GridCommand
extends RefCounted

enum Type {
    STEP_FORWARD,
    STEP_BACK,
    MOVE_LEFT,
    MOVE_RIGHT,
    TURN_LEFT,
    TURN_RIGHT,
    USE_SLOT_1,
    USE_SLOT_2,
    USE_SLOT_3,
    PICKUP,
    DROP_SLOT_1,
    DROP_SLOT_2,
    DROP_SLOT_3,
    CYCLE_TARGET_PREV,
    CYCLE_TARGET_NEXT,
    ANALYZE_TARGET,
    PASS_TURN,
    INTERACT,
}