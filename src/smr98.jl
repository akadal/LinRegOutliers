function distances(resids::Array{Float64,1}, fitteds::Array{Float64})::Array{Float64,2}
    n = length(resids)
    d = zeros(Float64, n, n)
    @inbounds for i in 1:n
        for j in i:n
            if i != j 
                p1 = [resids[i], fitteds[i]]
                p2 = [resids[j], fitteds[j]]
                d[i, j] = sqrt(sum((p1 .- p2).^2.0))
                d[j, i] = d[i, j]
            end
        end
    end
    return d
end

function majona(cluster::Hclust)::Float64
    heights = cluster.heights
    return mean(heights) + 1.25 * std(heights)
end

"""

    smr98(setting)

Perform the Sebert, Monthomery and Rollier (1998) algorithm for the given regression setting.

# Arguments
- `setting::RegressionSetting`: RegressionSetting object with a formula and dataset.

# Examples
```julia-repl
julia> reg0001 = createRegressionSetting(@formula(calls ~ year), phones);
julia> smr98(reg0001)
10-element Array{Int64,1}:
 15
 16
 17
 18
 19
 20
 21
 22
 23
 24
```

# References
Sebert, David M., Douglas C. Montgomery, and Dwayne A. Rollier. "A clustering algorithm for 
identifying multiple outliers in linear regression." Computational statistics & data analysis 
27.4 (1998): 461-484.
"""
function smr98(setting::RegressionSetting)
    X = designMatrix(setting)
    y = responseVector(setting)
    return smr98(X, y)
end


"""

    smr98(X, y)

Perform the Sebert, Monthomery and Rollier (1998) algorithm for the given regression setting.

# Arguments
- `X::Array{Float64, 2}`: Desing matrix of the linear regression model.
- `y::Array{Float64, 1}`: Response vector of the linear regression model.


# References
Sebert, David M., Douglas C. Montgomery, and Dwayne A. Rollier. "A clustering algorithm for 
identifying multiple outliers in linear regression." Computational statistics & data analysis 
27.4 (1998): 461-484.
"""

function smr98(X::Array{Float64,2}, y::Array{Float64,1})
    olsreg = ols(X, y)
    stdres = standardize(ZScoreTransform, residuals(olsreg), dims=1)
    stdfit = standardize(ZScoreTransform, predict(olsreg), dims=1)
    n, p = size(X)
    d = distances(stdres, stdfit)
    h = floor((n + p - 1) / 2)
    hcl = hclust(d, linkage=:single)
    majonacrit = majona(hcl)
    clustermappings = cutree(hcl, h=majonacrit)
    uniquemappings = unique(clustermappings)
    for clustid in uniquemappings
        cnt = count(x -> x == clustid, clustermappings)
        if cnt >= h 
            return filter(i -> clustermappings[i] != clustid, 1:n)
        end
    end
    return []
end

