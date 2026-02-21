function w = simplex_cus(s)

epsw    = 1e-12;
s       = s - max(s, [], 1);
w       = exp(s);
w       = w ./ (sum(w,1) + epsw);

end
