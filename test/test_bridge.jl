using TestItemRunner

@testitem "Symbolics Bridge" begin
    using OpenSymbolicRules
    using Symbolics
    
    @variables x y
    D = Differential(x)
    
    # Differential(x)(y)
    symbolics_expr = D(y)
    
    unwrapped_expr = Symbolics.unwrap(symbolics_expr)
    
    # Bridge to OSR
    osr_expr = to_osr(unwrapped_expr)
    @test startswith(string(osr_expr), "Derivative(")
    
    # Bridge back
    back_expr = to_symbolics(osr_expr)
    @test isequal(back_expr, unwrapped_expr)
end
