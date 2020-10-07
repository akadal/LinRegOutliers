using Test
using DataFrames
using Random

include("outlier.jl")


@testset "Apply function to columns" begin
    ones_vector = ones(Float64, 10)
    zeros_vector = zeros(Float64, 10)
    mat = hcat(ones_vector, zeros_vector)

    @test applyColumns(sum, mat) == [10.0, 0.0]
    @test applyColumns(mean, mat) == [1.0, 0.0]
end

@testset "Basis - createRegressionSetting, designMatrix, responseVector" begin
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5],
        y=[2.0, 4, 6, 8, 10]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)

    @test designMatrix(setting) == hcat(ones(5), dataset[:, "x"])
    @test responseVector(setting) == dataset[:, "y"]
    @test setting.formula == @formula(y ~ x)
end

@testset "dffit - single case" begin
    # Since this regression setting is deterministic,
    # omission of a single observation has not an effect on
    # the predicted response.
    myeps = 10.0^(-6.0)
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5],
        y=[2.0, 4, 6, 8, 10]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    n, _ = size(dataset)
    for i in 1:n
        mydiff = dffit(setting, i)
        @test abs(mydiff) < myeps
    end
end

@testset "dffit - for all observations" begin
    # Since this regression setting is deterministic,
    # omission of a single observation has not an effect on
    # the predicted response.
    myeps = 10.0^(-6.0)
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5],
        y=[2.0, 4, 6, 8, 10]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    stats = dffit(setting)
    for element in stats
        @test abs(element) < myeps
    end
end

@testset "hat matrix" begin
    X = [1.0 1.0; 1.0 2.0; 1.0 3.0; 1.0 4.0; 1.0 5.0];
    hats_real = X * inv(X' * X) * X'
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5],
        y=[2.0, 4, 6, 8, 10]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    hats_calculated = hatmatrix(setting)

    @test hats_real == hats_calculated
end

@testset "studentized residuals" begin
    dataset = DataFrame(
        x=Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        y=Float64[2.1, 3.9, 6.2, 7.8, 11.0, 18.0]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    resi = studentizedResiduals(setting)
    @test abs(resi[1]) < 1.5
    @test abs(resi[2]) < 1.5
    @test abs(resi[3]) < 1.5
    @test abs(resi[4]) < 1.5
    @test abs(resi[5]) < 1.5
    @test abs(resi[6]) > 1.5
end


@testset "adjusted residuals" begin
    eps = 0.0001
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5],
        y=[2.0, 4, 6, 8, 10]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    resi = adjustedResiduals(setting)
    for element in resi
        @test abs(element) < eps 
    end
end

@testset "Cook's distance - Phone data" begin
    eps = 0.00001
    setting = createRegressionSetting(@formula(calls ~ year), phones)
    knowncooks = [0.005344774190779771, 0.0017088194691033181, 0.00016624914057961155, 
                    3.16444525831206e-5, 0.0005395058666404081, 0.0014375008774859539, 
                    0.0024828140956511258, 0.0036279720445167277, 0.004357605989540906, 
                    0.005288503758364767, 0.006313578057565415, 0.0076561205696857254, 
                    0.009568574875389256, 0.009970039008782357, 0.02610396373381051, 
                    0.029272523880917646, 0.05091236198400663, 0.08176555044049343, 
                    0.14380266904640235, 0.26721539425047447, 0.051205153558783356, 
                    0.13401084683481085, 0.16860324592350226, 0.2172819114905912]
    cookdists = cooks(setting)
    @test map((x, y) -> abs(x - y) < eps, cookdists, knowncooks) == trues(24)
end


@testset "Jacknifed standard error of regression" begin
    eps = 0.00001
    dataset = DataFrame(
        x=[1.0, 2, 3, 4, 5000],
        y=[2.0, 4, 6, 8, 1000]
    )
    setting = createRegressionSetting(@formula(y ~ x), dataset)
    @test jacknifedS(setting, 1) != 0
    @test jacknifedS(setting, 2) != 0
    @test jacknifedS(setting, 3) != 0
    @test jacknifedS(setting, 4) != 0
    @test jacknifedS(setting, 5) < eps
end

@testset "Mahalanobis squared distances" begin
    myeps = 10.0^(-6.0)
    x = [1.0, 2.0, 3.0, 4.0, 5.0]
    y = reverse(x)
    y[1] = y[1] * 10.0
    x[1] = x[1] * 10.0
    datamat = DataFrame(x=x, y=y)
    dmat = mahalabonisSquaredMatrix(datamat)
    d = diag(dmat)
    @test abs(d[1] - 3.2) < myeps
    @test abs(d[2] - 2.0) < myeps
    @test abs(d[3] - 0.4) < myeps
    @test abs(d[4] - 0.4) < myeps
    @test abs(d[5] - 2.0) < myeps
end

@testset "Find nonzero minimum" begin
    arr = [0.0, 2.0, 0.0, 0.0, 0.0, 9.0, 1.0]
    val = find_minimum_nonzero(arr)
    @test val == 1.0
end



@testset "Hadi & Simonoff 1993 - initial subset" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    y[n - 1] = y[n - 1] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    subset = hs93initialset(reg)
    @test !(49 in subset)
    @test !(50 in subset)
end

@testset "Hadi & Simonoff 1993 - basic subset" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    y[n - 1] = y[n - 1] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    initialsubset = hs93initialset(reg)
    basicsubset = hs93basicsubset(reg, initialsubset)
    @test !(49 in basicsubset)
    @test !(50 in basicsubset)
end

@testset "Hadi & Simonoff 1993 - Algorithm" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    outset = hs93(reg)
    @test 50 in outset["outliers"]
end

@testset "Hadi & Simonoff 1993 - with Hadi & Simonoff random data" begin
    reg = createRegressionSetting(@formula(y ~ x1 + x2), hs93randomdata)
    outset = hs93(reg)
    @test 1 in outset["outliers"]
    @test 2 in outset["outliers"]
    @test 3 in outset["outliers"]
end

@testset "Kianifard & Swallow 1989 - Algorithm" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    outset = ks89(reg, alpha=0.1)
    @test 15 in outset
    @test 16 in outset
    @test 17 in outset
    @test 18 in outset
    @test 19 in outset
    @test 20 in outset

    df2 = stackloss
    reg2 = createRegressionSetting(@formula(stackloss ~ airflow + watertemp + acidcond), stackloss)
    outset2 = ks89(reg2)
    @test 4 in outset2
    @test 21 in outset2
end


@testset "Sebert & Montgomery & Rollier 1998 - Algorithm" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    y[n - 1] = y[n - 1] * 2.0
    y[n - 2] = y[n - 2] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    outset = smr98(reg)
    @test 49 in outset
    @test 50 in outset
end


@testset "LMS - Algorithm - Random data" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    y[n - 1] = y[n - 1] * 2.0
    y[n - 2] = y[n - 2] * 2.0
    x[n - 3] = x[n - 3] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    outset = lms(reg)["outliers"]
    @test 48 in outset
    @test 49 in outset
    @test 50 in outset
end


@testset "LMS - Algorithm - Phone data" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    outset = lms(reg)["outliers"]
    @test 15 in outset
    @test 16 in outset
    @test 17 in outset
    @test 18 in outset
    @test 19 in outset
    @test 20 in outset
    @test 21 in outset
end


@testset "LTS - Algorithm - Random data" begin
    # Create simple data
    rng = MersenneTwister(12345)
    n = 50
    x = collect(1:n)
    e = randn(rng, n) .* 2.0
    y = 5 .+ 5 .* x .+ e
    y[n] = y[n] * 2.0
    y[n - 1] = y[n - 1] * 2.0
    y[n - 2] = y[n - 2] * 2.0
    x[n - 3] = x[n - 3] * 2.0
    df = DataFrame(x=x, y=y)
    reg = createRegressionSetting(@formula(y ~ x), df)
    outset = lms(reg)["outliers"]
    @test 48 in outset
    @test 49 in outset
    @test 50 in outset
end

@testset "LTS - Algorithm - Phone data" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    outset = lts(reg)["outliers"]
    @test 15 in outset
    @test 16 in outset
    @test 17 in outset
    @test 18 in outset
    @test 19 in outset
    @test 20 in outset
    @test 21 in outset
end


@testset "MVE - Algorithm - Phone data" begin
    df = phones
    outset = mve(df)["outliers"]
    @test 15 in outset
    @test 16 in outset
    @test 17 in outset
    @test 18 in outset
    @test 19 in outset
    @test 20 in outset
    @test 21 in outset
end

@testset "MCD - Algorithm - Phone data" begin
    df = phones
    outset = mcd(df)["outliers"]
    @test 15 in outset
    @test 16 in outset
    @test 17 in outset
    @test 18 in outset
    @test 19 in outset
    @test 20 in outset
    @test 21 in outset
end


@testset "MVE & LTS Plot - Algorithm - Phone data" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = mveltsplot(reg, showplot=false)
    regulars = result["regular.points"]
    @test 1 in regulars
    @test 2 in regulars
    @test 3 in regulars
    @test 4 in regulars
    @test 5 in regulars
    @test 6 in regulars
    @test 7 in regulars
    @test 8 in regulars
    @test 9 in regulars
    @test 10 in regulars
    @test 11 in regulars
    @test 12 in regulars
    @test 13 in regulars
end


@testset "BCH - Algorithm - Hawkins & Bradu & Kass data" begin
    df = hbk
    reg = createRegressionSetting(@formula(y ~ x1 + x2 + x3), df)
    result = bch(reg)
    regulars = result["basic.subset"]
    for i in 15:75
        @test i in regulars
    end
end


@testset "PY95 - Algorithm - Hawkins & Bradu & Kass data" begin
    df = hbk
    reg = createRegressionSetting(@formula(y ~ x1 + x2 + x3), df)
    result = py95(reg)
    outliers = result["outliers"]
    for i in 1:14
        @test i in outliers
    end
end

@testset "satman2013 - Algorithm - Hawkins & Bradu & Kass data" begin
    df = hbk
    reg = createRegressionSetting(@formula(y ~ x1 + x2 + x3), df)
    result = satman2013(reg)
    outliers = result["outliers"]
    for i in 1:14
        @test i in outliers
    end
end

@testset "satman2015 - Algorithm - Phone data" begin
    @test dominates([1,2,4], [1,2,3])
    @test dominates([1,2,3], [0,1,2])
    @test !dominates([1,2,3], [1,2,3])
    @test !dominates([1,2,3], [1,2,4])

    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = satman2015(reg)
    outliers = result["outliers"]
    for i in 15:20
        @test i in outliers
    end
end


@testset "asm2000 - Algorithm - Phone data" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = asm2000(reg)
    outliers = result["outliers"]
    for i in 15:20
        @test i in outliers
    end
end

@testset "LAD - Algorithm" begin
    eps = 0.0001
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = lad(reg)
    betas = result["betas"]
    @test betas[1] < 0
    @test betas[2] > 0

    df2 = DataFrame(
        x=[1,2,3,4,5,6,7,8,9,10],
        y=[2,4,6,8,10,12,14,16,18,1000]
    )
    reg2 = createRegressionSetting(@formula(y ~ x), df2)
    result2 = lad(reg2)
    betas2 = result2["betas"]
    @test abs(betas2[1] - 0) < eps
    @test abs(betas2[2] - 2) < eps
end

@testset "LAD with (X, y)" begin
    eps = 0.0001
    df2 = DataFrame(
        x=Float64[1,2,3,4,5,6,7,8,9,10],
        y=Float64[2,4,6,8,10,12,14,16,18,1000]
    )
    n = length(df2[!, "x"])
    X = hcat(ones(Float64, n), df2[!, "x"])
    y = df2[!, "y"]
    result2 = lad(X, y)
    betas2 = result2["betas"]
    @test abs(betas2[1] - 0) < eps
    @test abs(betas2[2] - 2) < eps
end


@testset "LTA - Algorithm - Phone data" begin
    eps = 0.0001
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = lta(reg, exact=true)
    betas = result["betas"]
    @test abs(betas[1] - -55.5) < eps
    @test abs(betas[2] -  1.15) < eps
end

@testset "Hadi 1992 - Algorithm - with several case" begin
    phones_matrix = hcat(phones[:, "calls"], phones[:, "year"])
    result = hadi1992(phones_matrix)
    outlier_indices = result["outliers"]
    for i in 15:20
        @test i in outlier_indices
    end

    hbk_matrix = hcat(hbk[:, "x1"], hbk[:, "x2"], hbk[:, "x3"])
    hbk_n, hbk_p = size(hbk_matrix)
    result = hadi1992(hbk_matrix)
    outlier_indices = result["outliers"]
    for i in 15:hbk_n
        @test !(i in outlier_indices)
    end

end


@testset "gwcga - Algorithm - phone data" begin
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = gwcga(reg)
    clean_indices = result["clean.subset"]
    for i in 15:20
        @test !(i in clean_indices)
    end
end

@testset "Compact Genetic Algorithm" begin
    Random.seed!(12345)
    function fcost(bits)
        return sum(bits)
    end
    result = cga(chsize=10, costfunction=fcost, popsize=100)
    for element in result
        @test element == 0
    end
end

@testset "Floating-point Genetic Algorithm" begin
    Random.seed!(12345)
    fcost(genes) = (genes[1] - 3.14159265)^2 + (genes[2] - 2.71828)^2
    epsilon = 10.0^(-6.0)
    popsize = 30
    chsize = 2
    mins = [-100.0, -100.0]
    maxs = [100.0, 100.0]
    result = ga(popsize, chsize, fcost, mins, maxs, 0.90, 0.05, 1, 100)
    best::RealChromosome = result[1]

    @test length(result) == 30
    @test abs(best.genes[1] - 3.14159265) < epsilon
    @test abs(best.genes[2] - 2.71828) < epsilon
end

@testset "Satman(2012) (Csteps and GA based LTS) Algorithm - Phones data" begin
    Random.seed!(12345)
    epsilon = 10.0^(-3.0)
    df = phones
    reg = createRegressionSetting(@formula(calls ~ year), df)
    result = galts(reg)
    betas = result["betas"]
    @test abs(betas[1] - (-56.5219)) < epsilon
    @test abs(betas[2] - 1.16488) < epsilon
end

@testset "RANSAC (1981) Algorithm - Paper example" begin
    Random.seed!(12345)
    df = DataFrame(y=[0,1,2,3,3,4,10], x=[0,1,2,2,3,4,2])
    reg = createRegressionSetting(@formula(y ~ x), df)
    result = ransac(reg, t=0.8, w=0.85)
    @test result == [7]
end
