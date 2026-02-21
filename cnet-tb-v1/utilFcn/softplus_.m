function y = softplus_(x)
    y = max(x,0) + log(1 + exp(-abs(x)));
end
