extends GutTest


func test_reaction_matching_with_table() -> void:
    var table := ReactionTable.new()
    
    # Setup test rules
    var rule_v := ReactionRule.new()
    rule_v.required_property_a = &"wet"
    rule_v.required_property_b = &"volatile"
    
    var inert_out := ItemData.new()
    inert_out.item_name = "Inert Sludge"
    rule_v.result_item = inert_out
    
    table.rules = [rule_v]
    
    # Create test items
    var item_a := ItemData.new()
    item_a.properties = [&"wet"]
    
    var item_b := ItemData.new()
    item_b.properties = [&"volatile"]
    
    var result := table.get_reaction_result(item_a, item_b)
    assert_not_null(result)
    assert_eq(result.item_name, "Inert Sludge")


func test_no_reaction_returns_null() -> void:
    var table := ReactionTable.new()
    
    var item_a := ItemData.new()
    item_a.properties = [&"bone"]
    
    var item_b := ItemData.new()
    item_b.properties = [&"dust"]
    
    var result := table.get_reaction_result(item_a, item_b)
    assert_null(result)
