using TestItemRunner

@testitem "Symbolics Bridge" begin
    using OpenSymbolicRules
    using Symbolics
    using SymbolicUtils: operation, arguments
    
    @variables x y
    D = Differential(x)
    
    # Differential(x)(y)
    symbolics_expr = D(y)
    
    unwrapped_expr = Symbolics.unwrap(symbolics_expr)
    
    # Bridge to OSR
    osr_expr = to_osr(unwrapped_expr)
    @test isequal(operation(osr_expr), Derivative)
    lambda_term = only(arguments(osr_expr))
    @test isequal(operation(lambda_term), Lambda)
    @test isequal(arguments(lambda_term), [Symbolics.unwrap(x), Symbolics.unwrap(y)])
    
    # Bridge back
    back_expr = to_symbolics(osr_expr)
    @test isequal(back_expr, unwrapped_expr)
end
