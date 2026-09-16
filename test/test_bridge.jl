using TestItemRunner

@testitem "Symbolics Bridge" begin
    using OpenSymbolicRules
    using Symbolics
    
    @variables x y
    D = Differential(x)
    
    # Differential(x)(y)
    symbolics_expr = D(y)
    
    # Bridge to OSR
    osr_expr = bridge_to_osr(symbolics_expr)
    
    # It becomes Derivative(y, x). Note: since we used @variables, y and x are Nums.
    # bridge_to_osr converts the operation inside the Num if we unwrap it, but Rewriters.Postwalk
    # on Num might just wrap/unwrap automatically in Symbolics.
    # Actually, Symbolics.unwrap(osr_expr) will be a Term.
    
    # To properly test, we should unwrap symbolics_expr because bridge operates on SymbolicUtils types.
    unwrapped_expr = Symbolics.unwrap(symbolics_expr)
    
    osr_expr = bridge_to_osr(unwrapped_expr)
    @test startswith(string(osr_expr), "Derivative(")
    
    # Bridge back
    back_expr = bridge_from_osr(osr_expr, Differential=Differential)
    @test isequal(back_expr, unwrapped_expr)
end
