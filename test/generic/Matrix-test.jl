const RINGS = Dict(
   "exact ring"          => (ZZ,                 (-1000:1000,)),
   "exact field"         => (GF(7),              ()),
   "inexact ring"        => (RealField["t"][1],  (0:200, -1000:1000)),
   "inexact field"       => (RealField,          (-1000:1000,)),
   "non-integral domain" => (residue_ring(ZZ, 6)[1], (0:5,)),
   "fraction field"      => (QQ,                 (-1000:1000,)),
)

primes100 = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59,
61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139,
149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227,
229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311,
313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401,
409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491,
499, 503, 509, 521, 523, 541]


function randprime(n::Int)
   if n > 100 || n < 1
      throw(DomainError())
   end
   return primes100[rand(1:n)]
end

# Simulate user matrix type belonging to AbstractArray
# with getindex but no setindex!
struct MyTestMatrix{T} <: AbstractMatrix{T}
   d::T
   dim::Int
end

Base.getindex(a::MyTestMatrix{T}, r::Int, c::Int) where T = a.d

Base.size(a::MyTestMatrix{T}) where T = a.dim, a.dim

# Simulate user Field, together with a specialized matrix type
# (like ZZRingElem / ZZMatrix)
struct F2 <: AbstractAlgebra.Field end

Base.zero(::F2) = F2Elem(false)
Base.one(::F2) = F2Elem(true)
(::F2)() = F2Elem(false)

struct F2Elem <: AbstractAlgebra.FieldElem
   x::Bool
end

(::F2)(x::F2Elem) = x
Base.:-(x::F2Elem) = x
Base.:+(x::F2Elem, y::F2Elem) = F2Elem(x.x ⊻ y.x)
Base.inv(x::F2Elem) = x.x ? x : throw(DivideError())
Base.:*(x::F2Elem, y::F2Elem) = F2Elem(x.x * y.x)

Base.convert(::Type{F2Elem}, x::Integer) = F2Elem(x % Bool)
Base.:(==)(x::F2Elem, y::F2Elem) = x.x == y.x

AbstractAlgebra.parent_type(::Type{F2Elem}) = F2
AbstractAlgebra.elem_type(::Type{F2}) = F2Elem
AbstractAlgebra.parent(x::F2Elem) = F2()
AbstractAlgebra.mul!(x::F2Elem, y::F2Elem, z::F2Elem) = y * z
AbstractAlgebra.add!(x::F2Elem, y::F2Elem) = x + y
AbstractAlgebra.divexact(x::F2Elem, y::F2Elem) = y.x ? x : throw(DivideError())

Random.rand(rng::AbstractRNG, sp::Random.SamplerTrivial{F2}) = F2Elem(rand(rng, Bool))
Random.gentype(::Type{F2}) = F2Elem

const F2MatSpace = MatSpace{F2Elem}

(S::F2MatSpace)() = zero_matrix(F2(), S.nrows, S.ncols)

struct F2Matrix <: AbstractAlgebra.MatElem{F2Elem}
   m::Generic.MatSpaceElem{F2Elem}
end

F2Matrix(::F2, ::UndefInitializer, r::Int, c::Int) = F2Matrix(Generic.MatSpaceElem{F2Elem}(F2(), undef, r, c))

AbstractAlgebra.elem_type(::Type{F2MatSpace}) = F2Matrix
AbstractAlgebra.parent_type(::Type{F2Matrix}) = F2MatSpace

AbstractAlgebra.base_ring(::F2MatSpace) = F2()
AbstractAlgebra.dense_matrix_type(::Type{F2Elem}) = F2Matrix
AbstractAlgebra.matrix_space(::F2, r::Int, c::Int) = F2MatSpace(F2(), r, c)

AbstractAlgebra.number_of_rows(a::F2Matrix) = nrows(a.m)
AbstractAlgebra.number_of_columns(a::F2Matrix) = ncols(a.m)
AbstractAlgebra.base_ring(::F2Matrix) = F2()

Base.getindex(a::F2Matrix, r::Int64, c::Int64) = a.m[r, c]
Base.setindex!(a::F2Matrix, x::F2Elem, r::Int64, c::Int64) = a.m[r, c] = x

function AbstractAlgebra.zero_matrix(R::F2, r::Int, c::Int)
   mat = Matrix{F2Elem}(undef, r, c)
   for i=1:r, j=1:c
      mat[i, j] = zero(R)
   end
   z = Generic.MatSpaceElem{F2Elem}(R, mat)
   return F2Matrix(z)
end

function AbstractAlgebra.matrix(R::F2, mat::AbstractMatrix{F2Elem})
   mat = convert(Matrix, mat)
   z = Generic.MatSpaceElem{F2Elem}(R, mat)
   return F2Matrix(z)
end

function AbstractAlgebra.matrix(R::F2, r::Int, c::Int, mat::AbstractMatrix{F2Elem})
   AbstractAlgebra._check_dim(r, c, mat)
   matrix(R, mat)
end

@testset "Generic.Mat.constructors" begin
   R, t = polynomial_ring(QQ, "t")

   @test_throws ErrorException matrix_space(R, -1, 5)
   @test_throws ErrorException matrix_space(R, 0, -2)
   @test_throws ErrorException matrix_space(R, -3, -4)

   S = matrix_space(R, 3, 3)

   @test S === matrix_space(R, 3, 3)

   @test elem_type(S) == Generic.MatSpaceElem{elem_type(R)}
   @test elem_type(MatSpace{elem_type(R)}) == Generic.MatSpaceElem{elem_type(R)}
   @test parent_type(Generic.MatSpaceElem{elem_type(R)}) == MatSpace{elem_type(R)}
   @test base_ring_type(MatSpace{elem_type(R)}) == typeof(R)
   @test base_ring_type(Generic.MatSpaceElem{elem_type(R)}) == typeof(R)
   @test base_ring_type(S) == typeof(R)
   @test base_ring(S) == R
   @test nrows(S) == 3
   @test ncols(S) == 3

   @test S isa MatSpace

   f = S(t^2 + 1)

   @test isa(f, MatElem)
   @test parent_type(f) == typeof(S)
   @test base_ring_type(f) == typeof(R)

   g = S(2)

   @test isa(g, MatElem)

   h = S(BigInt(23))

   @test isa(h, MatElem)

   k = S([t t + 2 t^2 + 3t + 1; 2t R(2) t + 1; t^2 + 2 t + 1 R(0)])

   @test isa(k, MatElem)

   @test k == S(k)

   S2 = matrix_space(R, 2, 2)
   @test_throws ErrorConstrDimMismatch S2(k)

   SZ = matrix_space(ZZ, 3, 3)
   @test_throws Exception SZ(k)

   R2, = residue_ring(ZZ, 2)
   R3, = residue_ring(ZZ, 3)
   R2_1x2 = matrix_space(R2, 1, 2)
   R3_1x2 = matrix_space(R3, 1, 2)
   m2 = R2_1x2([0, 1])
   @test_throws DomainError R3_1x2(m2)

   m = S()

   @test isa(m, MatElem)

   @test_throws ErrorConstrDimMismatch S([t t^2 ; t^3 t^4])
   @test_throws ErrorConstrDimMismatch S([t t^2 t^3 ; t^4 t^5 t^6 ; t^7 t^8 t^9 ; t t^2 t^3])
   @test_throws ErrorConstrDimMismatch S([t, t^2])
   @test_throws ErrorConstrDimMismatch S([t, t^2, t^3, t^4, t^5, t^6, t^7, t^8, t^9, t^10])

   # test literal construction
   for T = (R, ZZ)
      m = T[1 2]
      @test m isa MatElem{elem_type(T)}
      @test size(m) == (1, 2)
      @test m[1, 1] == T(1)
      @test m[1, 2] == T(2)

      m = T[1; 2; 3]
      @test m isa MatElem{elem_type(T)}
      @test size(m) == (3, 1)
      @test m[1, 1] == T(1)
      @test m[2, 1] == T(2)
      @test m[3, 1] == T(3)

      m = T[1 2; 3 4; 5 6]
      @test m isa MatElem{elem_type(T)}
      @test size(m) == (3, 2)
      @test m[1, 1] == T(1)
      @test m[1, 2] == T(2)
      @test m[2, 1] == T(3)
      @test m[2, 2] == T(4)
      @test m[3, 1] == T(5)
      @test m[3, 2] == T(6)

      @test T[1;] == matrix(T, 1, 1, [1])
      @test T[[1 2; 3 4];] == matrix(T, [1 2; 3 4])
      @test T[[1 2]; 3 4] == matrix(T, [1 2; 3 4])
      @test T[1:4;] == matrix(T, 4, 1, 1:4)
      @test T[[];] == matrix(T, 0, 0, [])
      @test T[[] ()...] == matrix(T, 0, 1, [])
      @test T[[] []] == matrix(T, 0, 2, [])
      @test T[;] == matrix(T, 0, 0, [])
      @test T[;;] == matrix(T, 0, 0, [])
      @test T[1;;] == matrix(T, 1, 1, [1])
      @test T[[1 2; 3 4];;] == matrix(T, [1 2; 3 4])
      @test T[[1; 3];; 2; 4] == matrix(T, [1 2; 3 4])
      @test T[1:4;; 5:8] == matrix(T, [1 5; 2 6; 3 7; 4 8])
      @test_throws MethodError T[;;;]
      @test_throws MethodError T[1;;;]

      if VERSION < v"1.11.2"
         @test_throws ArgumentError T[1; 2 3]
      else
         @test_throws DimensionMismatch T[1; 2 3]
      end
   end

   arr = [1 2; 3 4]
   arr2 = [1, 2, 3, 4, 5, 6]

   for T in [R, Int, BigInt, Rational{Int}, Rational{BigInt}]
      for M in (matrix(R, map(T, arr)),
                matrix(R, 2, 2, map(T, arr)))
         @test isa(M, Generic.MatSpaceElem{elem_type(R)})
         @test M.base_ring == R
         @test nrows(M) == 2
         @test ncols(M) == 2
      end
      @test_throws ErrorConstrDimMismatch matrix(R, 2, 3, map(T, arr))

      M2 = matrix(R, 2, 3, map(T, arr2))
      @test isa(M2, Generic.MatSpaceElem{elem_type(R)})
      @test M2.base_ring == R
      @test nrows(M2) == 2
      @test ncols(M2) == 3
      @test_throws ErrorConstrDimMismatch matrix(R, 2, 2, map(T, arr2))
      @test_throws ErrorConstrDimMismatch matrix(R, 2, 4, map(T, arr2))
   end

   M = matrix(R, transpose(arr))
   @test isa(M, Generic.MatSpaceElem{elem_type(R)})

   M = matrix(R, 2, 3, view(transpose(arr2), 1:6))
   @test isa(M, Generic.MatSpaceElem{elem_type(R)})

   M3 = zero_matrix(R, 2, 3)

   @test isa(M3, Generic.MatSpaceElem{elem_type(R)})
   @test M3.base_ring == R

   M4 = identity_matrix(R, 3)

   @test isa(M4, Generic.MatSpaceElem{elem_type(R)})
   @test M4.base_ring == R

   @test_throws DomainError identity_matrix(M3) # must be square

   M5 = ones_matrix(R, 2, 3)

   @test isa(M5, Generic.MatSpaceElem{elem_type(R)})
   @test base_ring(M5) == R
   @test all(isone, M5)

   # identity_matrix should preserve the type of the input
   M9 = matrix(F2(), F2Elem[1 0; 0 1])
   @test typeof(identity_matrix(M9))      == typeof(M9)
   @test typeof(identity_matrix(M9, 3))   == typeof(M9)
   @test typeof(identity_matrix(M9.m))    == typeof(M9.m)
   @test typeof(identity_matrix(M9.m, 3)) == typeof(M9.m)

   D1 = diagonal_matrix(one(R), 2)

   @test size(D1) == (2, 2)
   @test base_ring(D1) == R
   @test D1[1, 1] == D1[2, 2] == one(R)
   @test D1[1, 2] == D1[2, 1] == zero(R)
   @test D1 isa Generic.MatSpaceElem{elem_type(R)}

   D2 = diagonal_matrix(one(R), 2, 2)
   @test D2 == D1 && typeof(D2) == typeof(D1)

   let pol = t^2+1
      D3 = diagonal_matrix(pol, 3, 4)
      @test D3 isa Generic.MatSpaceElem{elem_type(R)}
      for i=1:3, j=1:4
         if i == j
            @test D3[i, j] == pol
         else
            @test is_zero_entry(D3, i, j)
         end
      end
   end

   x = zero_matrix(R, 2, 2)
   y = zero_matrix(ZZ, 2, 3)

   @test x in [x, y]
   @test x in [y, x]
   @test !(x in [y])

   @test x in keys(Dict(x => 1))
   @test !(y in keys(Dict(x => 1)))

   # Test creation from AbstractArray without setindex!
   A = MyTestMatrix(BigInt(3), 2)
   S = matrix_space(ZZ, 2, 2)

   @test isa(S(A), Generic.MatSpaceElem{BigInt})

   # Test original matrix not modified
   S = matrix_space(QQ, 2, 2)
   a = Rational{BigInt}(1)
   A = [a a; a a]
   M = S(A)

   @test A[1, 1] === a

   a = BigInt(1)
   A = [a a; a a]
   M = S(A)

   @test A[1, 1] === a

   M1 = [1 2; 3 4]
   N1 = [5 6 7; 8 9 10]
   K1 = Matrix{Int}(undef, (2, 0))

   M = matrix(ZZ, M1)
   N = matrix(ZZ, N1)
   K = matrix(ZZ, K1)

   @test matrix(ZZ, M) == M
   @test matrix(ZZ, N) == N

   @test block_diagonal_matrix([M, N, K]) == matrix(ZZ, [1 2 0 0 0; 3 4 0 0 0; 0 0 5 6 7; 0 0 8 9 10; 0 0 0 0 0; 0 0 0 0 0])
   @test block_diagonal_matrix([K]) == matrix(ZZ, 2, 0, [])

   @test block_diagonal_matrix(ZZ, Matrix{Int}[]) == matrix(ZZ, 0, 0, [])
   @test block_diagonal_matrix(ZZ, [M1, N1, K1]) == block_diagonal_matrix([M, N, K])
   @test block_diagonal_matrix(ZZ, [K1]) == block_diagonal_matrix([K])

   # Test constructors over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)

   @test isa(S, MatSpace)

   @test base_ring(S) == R

   @test elem_type(S) == Generic.MatSpaceElem{elem_type(R)}
   @test elem_type(MatSpace{elem_type(R)}) == Generic.MatSpaceElem{elem_type(R)}
   @test parent_type(Generic.MatSpaceElem{elem_type(R)}) == MatSpace{elem_type(R)}

   @test dense_matrix_type(R) == elem_type(S)
   @test dense_matrix_type(R(1)) == elem_type(S)
   @test dense_matrix_type(typeof(R)) == elem_type(S)
   @test dense_matrix_type(typeof(R(1))) == elem_type(S)

   @test base_ring_type(dense_matrix_type(R)) == typeof(R)

   @test isa(S(), MatElem)
   @test isa(S(ZZ(1)), MatElem)
   @test isa(S(one(R)), MatElem)
   @test isa(S([1 2; 3 4]), MatElem)
   @test isa(S([1, 2, 3, 4]), MatElem)

   @test parent(S()) == S

   @test isa(zero_matrix(R, 2, 2), MatElem)
   @test isa(identity_matrix(R, 2), MatElem)

   @test isa(matrix(R, 2, 2, [1 2; 3 4]), MatElem)

   # these are not supported
   # @test isa(matrix(R, 2, 2, [[1 2; 3 4] [2 3; 4 5]; [3 4; 5 6] [4 5; 6 7]]), MatElem)
   # @test isa(matrix(R, 2, 2, [matrix(R, [1 2; 3 4]) matrix(R, [2 3; 3 4]); matrix(R, [3 4; 5 6]) matrix(R, [4 5; 6 7])]), MatElem)
   # @test isa(matrix(R,  matrix(R, [R([1 2; 3 4]) R([2 3; 3 4]); R([3 4; 5 6]) R([4 5; 6 7])]), MatElem)

   A = [1 2; 3 4]
   B = [2 3; 4 5]
   C = [3 4; 5 6]
   D = [4 5; 6 7]

   RA = R(A)
   RB = R(B)
   RC = R(C)
   RD = R(D)

   @test isa(matrix(R, 2, 2, [A, B, C, D]), MatElem)
   @test isa(matrix(R, 2, 2, [RA, RB, RC, RD]), MatElem)

   @test isa(block_diagonal_matrix(R, [A, B]), MatElem)

   # the following is not supported
   # @test isa(block_diagonal_matrix([RA, RB]), MatElem)
end

@testset "construct triangular matrices" begin
   L1 = [1]
   L2 = [1, 2, 3]
   L3 = Int[]
   L4 = [1, 2, 3, 4]

   @test lower_triangular_matrix(L1) == matrix(ZZ, 1, 1, [1]);
   @test upper_triangular_matrix(L1) == matrix(ZZ, 1, 1, [1]);
   @test strictly_lower_triangular_matrix(L1) == matrix(ZZ, 2, 2, [0, 0, 1, 0]);
   @test strictly_upper_triangular_matrix(L1) == matrix(ZZ, 2, 2, [0, 1, 0, 0]);

   @test lower_triangular_matrix(L2) == matrix(ZZ, 2, 2, [1, 0, 2, 3]);
   @test upper_triangular_matrix(L2) == matrix(ZZ, 2, 2, [1, 2, 0, 3]);
   @test strictly_lower_triangular_matrix(L2) == matrix(ZZ, 3, 3, [0, 0, 0, 1, 0, 0, 2, 3, 0]);
   @test strictly_upper_triangular_matrix(L2) == matrix(ZZ, 3, 3, [0, 1, 2, 0, 0, 3, 0, 0, 0]);

   for L in [L3, L4]
     @test_throws ArgumentError lower_triangular_matrix(L)
     @test_throws ArgumentError upper_triangular_matrix(L)
     @test_throws ArgumentError strictly_lower_triangular_matrix(L)
     @test_throws ArgumentError strictly_upper_triangular_matrix(L)
   end
end

@testset "Generic.Mat.size/axes" begin
   A = matrix(QQ, [1 2 3; 4 5 6; 7 8 9])
   B = matrix(QQ, [1 2 3 4; 5 6 7 8])

   @test size(A) == (3,3)
   @test size(A, 1) == 3
   @test size(A, 2) == 3
   @test size(A, rand(3:99)) == 1
   @test_throws BoundsError size(A, 0)
   @test_throws BoundsError size(A, -rand(1:99))

   @test axes(A) == (1:3, 1:3)
   @test axes(A, 1) == 1:3
   @test axes(A, 2) == 1:3
   @test axes(A, rand(3:99)) == 1:1
   @test_throws BoundsError axes(A, 0)
   @test_throws BoundsError axes(A, -rand(1:99))

   @test is_square(A)

   @test A[1:end, 1:end] == A
   @test firstindex(A, 1) == 1
   @test lastindex(A, 1) == nrows(A)
   @test lastindex(A, 2) == ncols(A)
   @test_throws ErrorException lastindex(A, 3)

   @test size(B) == (2,4)
   @test size(B, 1) == 2
   @test size(B, 2) == 4
   @test size(B, rand(3:99)) == 1
   @test_throws BoundsError size(B, 0)
   @test_throws BoundsError size(B, -rand(1:99))

   @test axes(B) == (1:2, 1:4)
   @test axes(B, 1) == 1:2
   @test axes(B, 2) == 1:4
   @test axes(B, rand(3:99)) == 1:1
   @test_throws BoundsError axes(A, 0)
   @test_throws BoundsError axes(A, -rand(1:99))

   @test B[1:end, 1:end] == B
   @test firstindex(B, 1) == 1
   @test lastindex(B, 1) == nrows(B)
   @test lastindex(B, 2) == ncols(B)
   @test_throws ErrorException lastindex(B, 3)

   @test !is_square(B)

   # test over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)

   M = rand(S, -10:10)

   @test firstindex(M, 1) == 1
   @test lastindex(M, 1) == 2
   @test size(M) == (2, 2)
   @test size(M, 1) == 2
   @test axes(M) == (1:2, 1:2)
   @test axes(M, 1) == 1:2
   @test is_square(M)
end

@testset "Generic.Mat.manipulation" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])
   B = S([R(2) R(3) R(1); t t + 1 t + 2; R(-1) t^2 t^3])

   @test nrows(S) == 3
   @test ncols(S) == 3

   @test dense_matrix_type(R) == elem_type(S)

   let ET = AbstractAlgebra.Generic.Poly{Rational{BigInt}}
      @test eltype(typeof(A)) == eltype(A) == elem_type(base_ring(A)) == ET
      @test eltype(typeof(B)) == eltype(B) == elem_type(base_ring(B)) == ET
   end

   @test iszero(zero(S))
   @test isone(one(S))

   @test zero(A) == zero(S)
   @test one(A) == one(S)

   B[1, 1] = R(3)
   @test B[1, 1] == R(3)

   B[1, 1] = 4
   @test B[1, 1] == R(4)

   B[1, 1] = BigInt(5)
   @test B[1, 1] == R(5)

   @test nrows(B) == 3
   @test ncols(B) == 3

   let AA = deepcopy(A)
      @test AA == A
      @test AA[1,1] !== A[1,1]
   end

   let AA = copy(A)
      @test AA == A
      @test AA[1,1] === A[1,1]
   end

   C = S([t + 1 R(0) R(1); t^2 R(0) t; R(0) R(0) R(0)])

   @test is_zero_entry(C, 1, 2)
   @test !is_zero_entry(C, 1, 1)
   @test is_zero_row(C, 3)
   @test !is_zero_row(C, 1)
   @test is_zero_column(C, 2)
   @test !is_zero_column(C, 1)

   @test_throws BoundsError is_zero_row(C, 0)
   @test_throws BoundsError is_zero_row(C, 4)
   @test_throws BoundsError is_zero_column(C, 0)
   @test_throws BoundsError is_zero_column(C, 4)

   @test length(A) == length(B) == length(C) == 9
   @test !any(isempty, (A, B, C))

   @test length(matrix(R, zeros(Int, 2, 3))) == 6

   n = matrix(R, zeros(Int, 3, 2))
   @test length(n) == 6
   let ET = AbstractAlgebra.Generic.Poly{Rational{BigInt}}
      @test eltype(typeof(n)) == ET
      @test eltype(n) == ET
      @test elem_type(base_ring(n)) == ET
   end

   for n = (matrix(R, zeros(Int, 2, 0)),
            matrix(R, zeros(Int, 0, 2)))
      @test length(n) == 0
      @test isempty(n)
   end

   M3 = matrix_ring(R, 3)
   for m3 in [rand(M3, -1:9, -9:9),
              rand(rng, M3, -1:9, -9:9),
              randmat_triu(M3, -1:9, -9:9),
              randmat_triu(rng, M3, -1:9, -9:9),
              randmat_with_rank(M3, 2, -1:9, -9:9),
              randmat_with_rank(rng, M3, 2, -1:9, -9:9)]
      @test length(m3) == 9
      ET = AbstractAlgebra.Generic.Poly{Rational{BigInt}}
      @test eltype(typeof(m3)) == ET
      @test eltype(m3) == ET
      @test elem_type(base_ring(m3)) == ET
      @test !isempty(m3)
      @test !iszero(m3)
      @test m3 isa Generic.MatRingElem
      @test parent(m3) == M3
   end

   M0 = matrix_ring(R, 0)
   m0 = rand(M0, -1:9, -9:9)
   @test length(m0) == 0
   @test isempty(m0)

   M45 = matrix_space(R, 4, 5)
   for m45 in [rand(M45, -1:9, -9:9),
               rand(rng, M45, -1:9, -9:9),
               randmat_triu(M45, -1:9, -9:9),
               randmat_triu(rng, M45, -1:9, -9:9),
               randmat_with_rank(M45, 3, -1:9, -9:9),
               randmat_with_rank(rng, M45, 3, -1:9, -9:9)]
      @test length(m45) == 20
      @test !iszero(m45)
      @test m45 isa Generic.MatSpaceElem
      @test parent(m45) == M45
      @test_throws DomainError one(m45)
   end

   @test_throws DomainError one(M45)

   let m = matrix(ZZ, 2, 3, 1:6)
      @test typeof(m[1, 1]) == BigInt # not in AbstractAlgebra's hierarchy
      @test eltype(m) == BigInt
      @test eltype(typeof(m)) == BigInt
   end

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)

   M = rand(S, -10:10)

   @test isa(hash(M), UInt)
   @test nrows(M) == 2
   @test ncols(M) == 2
   @test length(M) == 4
   @test isempty(M) == false
   @test isassigned(M, 1, 1) == true

   @test iszero(zero(M, 3, 3))
   @test iszero(zero(M, QQ, 3, 3))
   @test iszero(zero(M, QQ))
   
   M = zero!(M)
   @test iszero(M)

   @test isone(one(R))

   @test is_zero_row(M, 1)
   @test is_zero_column(M, 1)
end

@testset "Generic.Mat.unary_ops" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])
   B = S([-t - 1 (-t) -R(1); -t^2 (-t) (-t); -R(-2) (-t - 2) (-t^2 - t - 1)])

   @test -A == B

   # Exact ring
   S = matrix_space(ZZ, rand(0:9), rand(0:9))
   A = rand(S, -1000:1000)

   @test iszero(A + (-A))
   @test A == -(-A)
   @test -A == S(-A.entries)

   # Exact field
   S = matrix_space(GF(7), rand(0:9), rand(0:9))
   A = rand(S)

   @test iszero(A + (-A))
   @test A == -(-A)
   @test -A == S(-A.entries)

   # Inexact ring
   S = matrix_space(RealField["t"][1], rand(0:9), rand(0:9))
   A = rand(S, 0:200, -1000:1000)

   @test iszero(A + (-A))
   @test A == -(-A)
   @test -A == S(-A.entries)

   # Inexact field
   S = matrix_space(RealField, rand(0:9), rand(0:9))
   A = rand(S, -1000:1000)

   @test iszero(A + (-A))
   @test A == -(-A)
   @test -A == S(-A.entries)

   # Non-integral domain
   S = matrix_space(residue_ring(ZZ, 6)[1], rand(0:9), rand(0:9))
   A = rand(S, 0:5)

   @test iszero(A + (-A))
   @test A == -(-A)
   @test -A == S(-A.entries)

   z = zero_matrix(F2(), 2, 3)
   @test -z   isa F2Matrix
   @test -z.m isa Generic.MatSpaceElem{F2Elem}

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)

   M = rand(S, -10:10)

   @test -(-M) == M
end

@testset "Generic.Mat.getindex" begin
   S = matrix_space(ZZ, 3, 3)

   A = S([1 2 3; 4 5 6; 7 8 9])

   B = @inferred A[1:2, 1:2]

   @test typeof(B) == typeof(A)
   @test B == matrix_space(ZZ, 2, 2)([1 2; 4 5])

   B[1, 1] = 10
   @test A == S([1 2 3; 4 5 6; 7 8 9])

   C = @inferred B[1:2, 1:2]

   @test typeof(C) == typeof(A)
   @test C == matrix_space(ZZ, 2, 2)([10 2; 4 5])

   C[1, 1] = 20
   @test B == matrix_space(ZZ, 2, 2)([10 2; 4 5])
   @test A == S([1 2 3; 4 5 6; 7 8 9])

   D = @inferred A[:, 2:3]

   @test D == matrix(ZZ, 3, 2, [2, 3, 5, 6, 8, 9])

   @test A == @inferred A[:, :]
   @test B == @inferred B[:, :]
   @test C == @inferred C[:, :]
   @test D == @inferred D[:, :]

   # bounds check
   S = matrix_space(ZZ, rand(1:9), 0)
   A = S()
   @test isempty(A)
   rows = UnitRange(extrema(rand(axes(A)[1], 2))...)
   # A[rows, :] must be a valid indexing
   @test size(A[rows, :]) == (length(rows), 0)
   @test_throws BoundsError A[1:10, :]

   S = matrix_space(ZZ, 0, rand(1:9))
   A = S()
   @test isempty(A)
   cols = UnitRange(extrema(rand(axes(A)[2], 2))...)
   # A[:, cols] must be a valid indexing
   @test size(A[:, cols]) == (0, length(cols))
   @test_throws BoundsError A[:, 1:10]

   S = matrix_space(ZZ, 0, 0)
   A = S()
   @test isempty(A)
   # A[:, :] must be a valid indexing
   @test size(A[:, :]) == (0, 0)
   @test_throws BoundsError A[2:3, 1:10]

   function test_linear_indexing(A)
      nr, nc = size(A)
      if nr == 1
         c = rand(1:nc)
         @test A[c] == A[1, c]
      elseif nc == 1
         r = rand(1:nr)
         @test A[r] == A[r, 1]
      elseif length(A) >= 1
         @test_throws ArgumentError A[1]
      end
      A = deepcopy(A)
      if nr == 1
         c = rand(1:nc)
         d = rand(1:nc)
         A[c] = A[d]
         @test A[c] == A[1, d]
      elseif nc == 1
         r = rand(1:nr)
         s = rand(1:nr)
         A[r] = A[s]
         @test A[r] == A[s, 1]
      elseif length(A) >= 1
         @test_throws ArgumentError (A[1] = zero(base_ring(A)))
      end
   end

   for (_, (R, rand_params)) in RINGS
      len = rand(1:9)
      A = matrix(R, 1, len, rand(make(R, rand_params...), len))
      test_linear_indexing(A)
      A = matrix(R, len, 1, rand(make(R, rand_params...), len))
      test_linear_indexing(A)
      A = matrix(R, 2, len, rand(make(R, rand_params...), 2*len))
      test_linear_indexing(A)
   end

   # Exact ring
   R = ZZ
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])

   test_linear_indexing(A)

   # Exact field
   R = GF(7)
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])

   test_linear_indexing(A)

   # Inexact ring
   R = RealField["t"][1]
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, 0:200, -1000:1000)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])

   test_linear_indexing(A)

   # Inexact field
   R = RealField
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])

   # Non-integral domain
   R, = residue_ring(ZZ, 6)
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, 0:5)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])

   # Fraction field
   R = QQ
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)
   ((i, j), (k, l)) = extrema.(rand.(axes(A), 2))

   @test A[i:j, k:l] == matrix(R, A.entries[i:j, k:l])
   @test A[:, k:l] == matrix(R, A.entries[:, k:l])
   @test A[i:j, :] == matrix(R, A.entries[i:j, :])
   @test A[[i:j;], [k:l;]] == matrix(R, A.entries[[i:j;], [k:l;]])
   @test A[i:2:j, k:2:l] == matrix(R, A.entries[i:2:j, k:2:l])

   rows, cols = randsubseq.(axes(A), rand(2))
   @test A[rows, cols] == matrix(R, A.entries[rows, cols])
end

@testset "Generic.Mat.array_interface" begin
   A = matrix(ZZ, [1 2 3; 4 5 6])
   B = copy(A)

   @test ndims(A) == 2

   @test size(A) == (2, 3)
   @test eachindex(A) == CartesianIndices((2, 3))

   # cartesian indexing
   for i in eachindex(A)
      @test A[i] == A.entries[i]
      B[i] = 2 * B[i]
      @test B[i] == B.entries[i] == 2 * A[i]
   end

   @test_throws BoundsError A[CartesianIndex(0, 1)]
   @test_throws BoundsError A[CartesianIndex(1, -1)]
   @test_throws BoundsError A[CartesianIndex(-rand(2:99), 1)]
   @test_throws BoundsError A[CartesianIndex(1, 4)]
   @test_throws BoundsError A[CartesianIndex(rand(3:99), 1)]

   # iteration
   for (i, x) in enumerate(A)
      @test A[Tuple(CartesianIndices(size(A))[i])...] == x
   end

   AC = collect(A)
   @test size(AC) == size(A)
   @test AC == A.entries

   # check iteration for empty matrices
   for sz in [(2, 0), (0, 2), (0, 0)]
      A = matrix(ZZ, sz..., BigInt[])
      AC = collect(A)
      @test AC isa Matrix{BigInt}
      @test size(AC) == sz
   end
end

@testset "Generic.Mat.block_replacement" begin
   _test_block_replacement = function(a, b, r, c)
      rr = r isa Colon ? (1:nrows(a)) : r
      cc = c isa Colon ? (1:ncols(a)) : c
      if (b isa Vector)
         all([a[i1, j1] == b[i + j - 1] for (i, i1) in enumerate(rr) for (j, j1) in enumerate(cc)])
      else
         all([a[i1, j1] == b[i, j] for (i, i1) in enumerate(rr) for (j, j1) in enumerate(cc)])
      end
   end

   S = matrix_space(ZZ, 9, 9)
   (r, c) = (rand(1:9), rand(1:9))
   T = matrix_space(ZZ, r, c)
   a = rand(S, -100:100)
   b = rand(T, -100:100)
   startr = rand(1:(9-r+1))
   endr = startr + r - 1
   startc = rand(1:(9-c+1))
   endc = startc + c - 1
   a[startr:endr, startc:endc] = b
   @test a[startr:endr, startc:endc] == b

   for i in 1:10
      n = rand(1:9)
      m = rand(1:9)
      S = matrix_space(ZZ, n, m)
      a = rand(S, -100:100)
      (r, c) = (rand(1:n), rand(1:m))
      T = matrix_space(zz, r, c)
      b = rand(T, -2:2)
      startr = rand(1:(n-r+1))
      endr = startr + r - 1
      startc = rand(1:(m-c+1))
      endc = startc + c - 1

      rrs = Int[]
      for j in 1:rand(1:n)
         rr = rand(1:n)
         while (rr in rrs)
            rr = rand(1:n)
         end
         push!(rrs, rr)
      end

      ccs = Int[]
      for j in 1:rand(1:m)
         cc = rand(1:m)
         while (cc in ccs)
            cc = rand(1:m)
         end
         push!(ccs, cc)
      end

      a[axes(b)...] = b
      @test _test_block_replacement(a, b, axes(b)...)

      for r in [rand(1:n), Colon(), rrs, startr:endr, Base.OneTo(rand(1:n))]
         for c in [rand(1:m), Colon(), ccs, startc:endc, Base.OneTo(rand(1:m))]
            if c isa Int && r isa Int
               continue
            end
            for R in [zz, ZZ]
               lr = r isa Colon ? nrows(a) : length(r)
               lc = c isa Colon ? ncols(a) : length(c)
               T = matrix_space(zz, lr, lc)
               b = rand(T, -2:2)
               aa = deepcopy(a)
               a[r, c] = b
               @test _test_block_replacement(a, b, r, c)
               bb = Matrix(b)
               aa[r, c] = bb
               @test _test_block_replacement(aa, bb, r, c)
            end
         end
      end
      for r in [rand(1:n)]
         for c in [rand(1:m), Colon(), ccs, startc:endc]
            if c isa Int && r isa Int
               continue
            end
            for R in [zz, ZZ]
               lr = r isa Colon ? nrows(a) : length(r)
               lc = c isa Colon ? ncols(a) : length(c)
               T = matrix_space(zz, lr, lc)
               _b = rand(T, -2:2)
               b = vec(Matrix(_b))
               a[r, c] = b
               @test _test_block_replacement(a, b, r, c)
            end
         end
      end
      for r in [rand(1:n), Colon(), rrs, startr:endr]
         for c in [rand(1:m)]
            if c isa Int && r isa Int
               continue
            end
            for R in [zz, ZZ]
               lr = r isa Colon ? nrows(a) : length(r)
               lc = c isa Colon ? ncols(a) : length(c)
               T = matrix_space(zz, lr, lc)
               _b = rand(T, -2:2)
               b = vec(Matrix(_b))
               a[r, c] = b
               @test _test_block_replacement(a, b, r, c)
            end
         end
      end

   end
end

@testset "Generic.Mat.binary_ops" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])
   B = S([R(2) R(3) R(1); t t + 1 t + 2; R(-1) t^2 t^3])

   @test A + B == S([t+3 t+3 R(2); t^2 + t 2*t+1 2*t+2; R(-3) t^2 + t + 2 t^3 + 1*t^2 + t + 1])

   @test A - B == S([t-1 t-3 R(0); t^2 - t R(-1) R(-2); R(-1) (-t^2 + t + 2) (-t^3 + t^2 + t + 1)])

   @test A*B == S([t^2 + 2*t + 1 2*t^2 + 4*t + 3 t^3 + t^2 + 3*t + 1; 3*t^2 - t (t^3 + 4*t^2 + t) t^4 + 2*t^2 + 2*t; t-5 t^4 + t^3 + 2*t^2 + 3*t - 4 t^5 + 1*t^4 + t^3 + t^2 + 4*t + 2])

   # Exact ring
   R = ZZ

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S, -1000:1000)
      B = rand(S, -1000:1000)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Exact field
   R = GF(7)

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S)
      B = rand(S)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Inexact ring
   R = RealField["t"][1]

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S, -1:20, -100:100)
      B = rand(S, -1:20, -100:100)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Inexact field
   R = RealField

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S, -1000:1000)
      B = rand(S, -1000:1000)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Non-integral domain
   R, = residue_ring(ZZ, 6)

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S, 0:5)
      B = rand(S, 0:5)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Fraction field
   R = QQ

   for S in (matrix_space(R, rand(1:9), rand(1:9)),
             let n = rand(1:9)
                matrix_space(R, n, n)
             end)

      A = rand(S, -1000:1000)
      B = rand(S, -1000:1000)

      @test A + B == S(A.entries + B.entries)
      @test A - B == S(A.entries - B.entries)
      @test A + B == A - (-B)
      if is_square(A)
         @test A * B == S(A.entries * B.entries)
      end
   end

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)
   N = rand(S, -10:10)
   P = rand(S, -10:10)
   
   @test M + N == N + M
   @test M - N == M + (-N)
   @test M*(N + P) == M*N + M*P
end

# add x to all the elements of the main diagonal of a copy of M
add_diag(M::Matrix, x) = [i != j ? M[i, j] : M[i, j] + x for (i, j) in Tuple.(CartesianIndices(M))]

@testset "Generic.Mat.adhoc_binary" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test 12 + A == A + 12
   @test BigInt(11) + A == A + BigInt(11)
   @test Rational{BigInt}(11) + A == A + Rational{BigInt}(11)
   @test (t + 1) + A == A + (t + 1)
   @test A - (t + 1) == -((t + 1) - A)
   @test A - 3 == -(3 - A)
   @test A - BigInt(7) == -(BigInt(7) - A)
   @test A - Rational{BigInt}(7) == -(Rational{BigInt}(7) - A)
   @test 3*A == A*3
   @test BigInt(3)*A == A*BigInt(3)
   @test Rational{BigInt}(3)*A == A*Rational{BigInt}(3)
   @test (t - 1)*A == A*(t - 1)

   # Exact ring
   R = ZZ
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R, -1000:1000)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   function _test_matrix_vector_prod(R, randargs...)
      A = rand(matrix_space(R, 3, 2), randargs...)
      v = elem_type(R)[rand(R, randargs...) for i in 1:2]
      @test A*v == [A[i,1]*v[1] + A[i,2]*v[2] for i in 1:nrows(A)]
      v = elem_type(R)[rand(R, randargs...) for i in 1:3]
      @test v*A == [v[1]*A[1,i] + v[2]*A[2,i] + v[3]*A[3,i] for i in 1:ncols(A)]

      A = rand(matrix_ring(R, 2), randargs...)
      v = elem_type(R)[rand(R, randargs...) for i in 1:2]
      @test A*v == [A[i,1]*v[1] + A[i,2]*v[2] for i in 1:nrows(A)]
      v = elem_type(R)[rand(R, randargs...) for i in 1:2]
      @test v*A == [v[1]*A[1,i] + v[2]*A[2,i] for i in 1:ncols(A)]

      A = rand(matrix_space(R, 0, 2), randargs...)
      v = elem_type(R)[rand(R, randargs...) for i in 1:2]
      @test A*v == elem_type(R)[]
      v = elem_type(R)[]
      @test v*A == [zero(R) for i in 1:ncols(A)]

      A = rand(matrix_space(R, 2, 0), randargs...)
      v = elem_type(R)[]
      @test A*v == [zero(R) for i in 1:nrows(A)]
      v = elem_type(R)[rand(R, randargs...) for i in 1:2]
      @test v*A == elem_type(R)[]
   end

   _test_matrix_vector_prod(R, -1000:1000)

   # Exact field
   R = GF(7)
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   _test_matrix_vector_prod(R)

   # Inexact ring
   R = RealField["t"][1]
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1:200, -1000:1000)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R, 0:200, -1000:1000)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   _test_matrix_vector_prod(R, -1:200, -1000:1000)

   # Inexact field
   R = RealField
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R, -1000:1000)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   _test_matrix_vector_prod(R, -1000:1000)

   # Non-integral domain
   R, = residue_ring(ZZ, 6)
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, 0:5)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R, 0:5)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   _test_matrix_vector_prod(R, 0:5)

   # Fraction field
   R = QQ
   S = matrix_space(R, rand(1:9), rand(1:9))

   A = rand(S, -1000:1000)

   for t in Any[rand(-1000:1000), big(rand(-1000:1000)), rand(R, -1000:1000)]
      @test A + t == t + A
      @test A + t == S(add_diag(A.entries, t))
      @test A - t == -(t - A)
      @test A - t == S(add_diag(A.entries, -t))
      @test A * t == t * A
      @test A * t == S(A.entries .* t)
   end

   _test_matrix_vector_prod(R, -1000:1000)

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)
   N = rand(S, -10:10)
   
   t1 = rand(ZZ, -10:10)
   t2 = rand(R, -10:10)

   @test t1*(M + N) == t1*M + t1*N
   @test t1*(M - N) == t1*M - t1*N
   @test (M + N)*t1 == M*t1 + N*t1
   @test (M - N)*t1 == M*t1 - N*t1

   @test t2*(M + N) == t2*M + t2*N
   @test t2*(M - N) == t2*M - t2*N
   @test (M + N)*t2 == M*t2 + N*t2
   @test (M - N)*t2 == M*t2 - N*t2

   @test M + t1 == M - (-t1)
   @test M + t2 == M - (-t2)

   @test t1 + M == t1 - (-M)
   @test t2 + M == t2 - (-M)

   r1 = rand(R, -10:10)
   r2 = rand(R, -10:10)

   @test (M + N)*[r1, r2] == M*[r1, r2] + N*[r1, r2]
   @test [r1, r2]*(M + N) == [r1, r2]*M + [r1, r2]*N
end

@testset "Generic.Mat.promotion" begin
   m = [1 2; 3 4]
   F, = residue_field(ZZ, 3)
   R, t = polynomial_ring(F, "t")
   A = matrix(R, m)
   B = matrix(F, m)

   @test typeof(A * B) == typeof(A)
   @test typeof(B * A) == typeof(A)
   @test A * B == A^2
   @test B * A == A^2
   
   @test typeof(A + B) == typeof(A)
   @test typeof(B + A) == typeof(A)
   @test A + B == A + A
   @test B + A == A + A

   @test typeof(F(2) * A) == typeof(A)
   @test typeof(A * F(2)) == typeof(A)
   @test F(2) * A == R(2) * A
   @test A * F(2) == A * R(2)

   @test typeof(F(2) + A) == typeof(A)
   @test typeof(A + F(2)) == typeof(A)
   @test F(2) + A == R(2) + A
   @test A + F(2) == A + R(2)

   @test one(F) == R[1 0; 0 1]
   @test R[1 0; 0 1] == one(R)

   # vector * matrix
   m = [1 2; 3 4]
   F, = residue_field(ZZ, 3)
   R, t = polynomial_ring(F, "t")
   A = matrix(R, m)
   B = matrix(F, m)
   v = [one(F), 2*one(F)]
   vv = [one(R), 2*one(R)]
   @test (@inferred A * v) == A * vv
   @test (@inferred v * A) == vv * A

   @test (@inferred B * vv) == A * vv
   @test (@inferred vv * B) == vv * A

   @test_throws ErrorException A * Rational{BigInt}[1 ,2]
   @test_throws ErrorException Rational{BigInt}[1 ,2] * A
end

@testset "Generic.Mat.permutation" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   T = SymmetricGroup(3)
   P = T([2, 3, 1])

   @test A == inv(P)*(P*A)

   @testset "$name" for (name, (R, randparams)) in RINGS
      S = matrix_space(R, rand(1:9), rand(0:9))
      A = rand(S, randparams...)
      T = SymmetricGroup(nrows(A))
      P = rand(T)
      Q = inv(P)

      PA = P*A
      @test PA == reduce(vcat, [A[Q[i]:Q[i], :] for i in 1:nrows(A)])
      @test PA == reduce(vcat, A[Q[i]:Q[i], :] for i in 1:nrows(A))
      @test PA == S(reduce(vcat, A.entries[Q[i], :] for i in 1:nrows(A)))
      @test A == Q*(P*A)
   end
end

@testset "Generic.Mat.comparison" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])
   B = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test A == B

   @test A != one(S)

   @testset "$name" for (name, (R, randparams)) in RINGS
      S = matrix_space(R, rand(1:9), rand(1:9))
      seed = rand(1:999)

      Random.seed!(rng, seed)
      A = rand(rng, S, randparams...)
      Random.seed!(rng, seed)
      B = rand(rng, S, randparams...)

      @test A == B
      @test A == A
      @test A == copy(A)

      for _=1:3
         i, j = rand.(Base.OneTo.(size(A)))
         x = A[i, j]
         iszero(x) && continue
         if x == -x
            @assert !(R isa AbstractAlgebra.Field) || characteristic(R) == 2  # could happen for GF(2)
            continue
         end
         B[i, j] = -A[i, j]
         @test B != A
         B[i, j] = -B[i, j]
         @test A == A
      end

      @test matrix(R, copy(A.entries)) == A
   end

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)
   N = deepcopy(M)
   
   @test M == M
   @test M == N
   @test M == copy(M)
   @test isequal(M, M)
   @test isequal(M, N)
   @test isequal(M, copy(M))
end

@testset "Generic.Mat.adhoc_comparison" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test S(12) == 12
   @test S(5) == BigInt(5)
   @test S(5) == Rational{BigInt}(5)
   @test S(t + 1) == t + 1
   @test 12 == S(12)
   @test BigInt(5) == S(5)
   @test Rational{BigInt}(5) == S(5)
   @test t + 1 == S(t + 1)
   @test A != one(S)
   @test one(S) == one(S)

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   @test S(5) == 5
   @test 5 == S(5)
   @test S(BigInt(5)) == 5
   @test 5 == S(BigInt(5))

   m = rand(R, -10:10)

   @test S(m) == m
   @test m == S(m)
end

@testset "Generic.Mat.powering" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test A^5 == A^2*A^3

   @test A^0 == one(S)

   S = matrix_space(QQ, 2, 2)

   A = S(Rational{BigInt}[2 3; 7 -4])

   @test A^-1 == inv(A)

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)

   @test M^0 == one(S)
   @test M^1 == M
   @test M^2 == M*M
   @test M^3 == M*M*M
end

@testset "Generic.Mat.adhoc_exact_division" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test divexact(5*A, 5) == A
   @test divexact(12*A, BigInt(12)) == A
   @test divexact(12*A, Rational{BigInt}(12)) == A
   @test divexact((1 + t)*A, 1 + t) == A

   Qx, x = QQ["x"]
   Qxy, y = polynomial_ring(Qx, "y")
   @test divexact(Qxy[2 0; 0 2], Qx(2)) == identity_matrix(Qxy, 2)
   @test divexact(Qxy[2 0; 0 2], Qx(2), check = false) == identity_matrix(Qxy, 2)
   @test divexact_left(Qxy[2 0; 0 2], Qx(2)) == identity_matrix(Qxy, 2)
   @test divexact_left(Qxy[2 0; 0 2], Qx(2), check = false) == identity_matrix(Qxy, 2)
   @test divexact_right(Qxy[2 0; 0 2], Qx(2)) == identity_matrix(Qxy, 2)
   @test divexact_right(Qxy[2 0; 0 2], Qx(2), check = false) == identity_matrix(Qxy, 2)

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   U, x = polynomial_ring(R, "x")

   S = matrix_space(R, 2, 2)
   T = matrix_space(U, 2, 2)

   for i = 1:50
       M = rand(S, -10:10)

       @test divexact(5*M, 5) == M

       c = rand(R, -10:10)
       while rank(c) != 2
          c = rand(R, -10:10)
       end

       @test divexact_left(c*M, c) == M
       @test divexact_right(M*c, c) == M

       N = rand(T, 0:5, -10:10)
       d = rand(U, 0:5, -10:10)
       while iszero(d) || rank(leading_coefficient(d)) != 2
          d = rand(U, 0:5, -10:10)
       end

       @test divexact_left(d*N, d) == N
       @test divexact_right(N*d, d) == N
   end
end

@testset "Generic.Mat.is_symmetric" begin
   R, t = polynomial_ring(QQ, "t")
   @test !is_symmetric(matrix(R, [t + 1 t R(1); t^2 t t]))
   @test is_symmetric(matrix(R, [t + 1 t R(1); t t^2 t; R(1) t R(5)]))
   @test !is_symmetric(matrix(R, [t + 1 t R(1); t + 1 t^2 t; R(1) t R(5)]))
   S = matrix_ring(R, 3)
   @test is_symmetric(S([t + 1 t R(1); t t^2 t; R(1) t R(5)]))
   @test !is_symmetric(S([t + 1 t R(1); t + 1 t^2 t; R(1) t R(5)]))

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)

   @test is_symmetric(M + transpose(M))
end

@testset "Generic.Mat.is_alternating" begin

  @testset "Test is_alternating for $R" for R in [GF(2), GF(3), ZZ, QQ]
     @test is_alternating(matrix(R, [0 1 ; -1 0]))
     @test !is_alternating(matrix(R, [1 1 ; -1 1]))
     @test !is_alternating(matrix(R, [1 0 ; 1 1]))
     @test !is_alternating(matrix(R, [0 1 0 ; -1 0 0]))
  end

  # Tests over noncommutative ring
  R = matrix_ring(ZZ, 2)
  S = matrix_space(R, 2, 2)
  M = rand(S, -10:10)

  @test is_alternating(M - transpose(M))
end

@testset "Generic.Mat.is_skew_symmetric" begin

   @testset "Test is_skew_symmetric for $R" for R in [GF(2), GF(3), ZZ, QQ]
      @test is_skew_symmetric(matrix(R, [0 1 ; -1 0]))
      @test is_skew_symmetric(matrix(R, [1 1 ; -1 1])) == (characteristic(R) == 2)
      @test !is_skew_symmetric(matrix(R, [1 0 ; 1 1]))
      @test !is_skew_symmetric(matrix(R, [0 1 0 ; -1 0 0]))
   end

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   S = matrix_space(R, 2, 2)
   M = rand(S, -10:10)

   @test is_skew_symmetric(M - transpose(M))
end

@testset "Generic.Mat.transpose" begin
   R, t = polynomial_ring(QQ, "t")
   arr = [t + 1 t R(1); t^2 t t]
   A = matrix(R, arr)
   B = matrix(R, permutedims(arr))
   @test transpose(A) == B

   arr = [t + 1 t; t^2 t]
   A = matrix(R, arr)
   B = matrix(R, permutedims(arr))
   @test transpose(A) == B

   # transpose input/output types are the same
   a = matrix(F2(), F2Elem[1 1 0; 0 0 1])
   # not method (yet) for transpose(a)
   at = transpose(a.m)
   @test typeof(at) == typeof(a.m)
   @test at[1, 1] == at[2, 1] == at[3, 2] == F2Elem(true)
   @test at[3, 1] == at[1, 2] == at[2, 2] == F2Elem(false)
end

@testset "Generic.Mat.gram" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test gram(A) == S([2*t^2 + 2*t + 2 t^3 + 2*t^2 + t 2*t^2 + t - 1; t^3 + 2*t^2 + t t^4 + 2*t^2 t^3 + 3*t; 2*t^2 + t - 1 t^3 + 3*t t^4 + 2*t^3 + 4*t^2 + 6*t + 9])
end

@testset "Generic.Mat.tr" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test tr(A) == t^2 + 3t + 2
end

@testset "Generic.Mat.content" begin
   R, t = polynomial_ring(QQ, "t")
   S = matrix_space(R, 3, 3)

   A = S([t + 1 t R(1); t^2 t t; R(-2) t + 2 t^2 + t + 1])

   @test content((1 + t)*A) == 1 + t
end

@testset "Generic.Mat.lu" begin
   # Exact field
   R = GF(7)

   for iters = 1:50
      m = rand(0:100)
      n = rand(0:100)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      A = randmat_with_rank(S, rank)

      r, P, L, U = lu(A)
      @test P*A == L*U
      @test r == rank
   end

   # Fraction field
   R = QQ

   for iters = 1:20
      m = rand(0:30)
      n = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      A = randmat_with_rank(S, rank, -10:10)

      r, P, L, U = lu(A)
      @test P*A == L*U
      @test r == rank
   end

   # Extra tests

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 3, 3)

   A = S([a + 1 2a + 3 a^2 + 1; 2a^2 - 1 a - 1 2a; a^2 + 3a + 1 2a K(1)])

   r, P, L, U = lu(A)

   @test r == 3
   @test P*A == L*U

   A = S([K(0) 2a + 3 a^2 + 1; a^2 - 2 a - 1 2a; a^2 + 3a + 1 2a K(1)])

   r, P, L, U = lu(A)

   @test r == 3
   @test P*A == L*U

   A = S([K(0) 2a + 3 a^2 + 1; a^2 - 2 a - 1 2a; a^2 - 2 a - 1 2a])

   r, P, L, U = lu(A)

   @test r == 2
   @test P*A == L*U

   R, z = polynomial_ring(ZZ, "z")
   F = fraction_field(R)

   A = matrix(F, 3, 3, [0, 0, 11, 78*z^3-102*z^2+48*z+12, 92, -16*z^2+80*z-149, -377*z^3+493*z^2-232*z-58, -448, 80*z^2-385*z+719])

   r, P, L, U = lu(A)

   @test r == 3
   @test P*A == L*U
end

@testset "Generic.Mat.fflu" begin
   # Exact ring
   R = ZZ

   for iters = 1:50
      m = rand(0:20)
      n = rand(0:20)

      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      A = S()
      for i = 1:m
         for j = 1:n
            A[i, j] = rand(-10:10)
         end
      end

      r, d, P, L, U = fflu(A)

      R2 = parent(1//one(R))
      V = matrix_space(R2, m, m)
      D = V()
      if m >= 1
          D[1, 1] = 1//L[1, 1]
      end
      if m >= 2
         for j = 1:m - 1
            D[j + 1, j + 1] = (1//L[j, j])*(1//L[j + 1, j + 1])
         end
      end
      L2 = change_base_ring(R2, L)
      U2 = change_base_ring(R2, U)
      @test change_base_ring(R2, P*A) == L2*D*U2
   end

 # Other tests

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 3, 3)

   A = S([a + 1 2a + 3 a^2 + 1; 2a^2 - 1 a - 1 2a; a^2 + 3a + 1 2a K(1)])

   r, d, P, L, U = fflu(A)

   D = S()
   D[1, 1] = inv(L[1, 1])
   D[2, 2] = inv(L[1, 1]*L[2, 2])
   D[3, 3] = inv(L[2, 2]*L[3, 3])

   @test r == 3
   @test P*A == L*D*U

   A = S([K(0) 2a + 3 a^2 + 1; a^2 - 2 a - 1 2a; a^2 + 3a + 1 2a K(1)])

   r, d, P, L, U = fflu(A)

   D = S()
   D[1, 1] = inv(L[1, 1])
   D[2, 2] = inv(L[1, 1]*L[2, 2])
   D[3, 3] = inv(L[2, 2]*L[3, 3])

   @test r == 3
   @test P*A == L*D*U

   A = S([K(0) 2a + 3 a^2 + 1; a^2 - 2 a - 1 2a; a^2 - 2 a - 1 2a])

   r, d, P, L, U = fflu(A)

   D = S()
   D[1, 1] = inv(L[1, 1])
   D[2, 2] = inv(L[1, 1]*L[2, 2])
   D[3, 3] = inv(L[2, 2]*L[3, 3])

   @test r == 2
   @test P*A == L*D*U

   A = matrix(QQ, 3, 3, [0, 0, 1, 12, 1, 11, 1, 0, 1])

   r, d, P, L, U, = fflu(A)

   D = zero_matrix(QQ, 3, 3)
   D[1, 1] = inv(L[1, 1])
   D[2, 2] = inv(L[1, 1]*L[2, 2])
   D[3, 3] = inv(L[2, 2]*L[3, 3])
   @test r == 3
   @test P*A == L*D*U
end

@testset "Generic.Mat.det" begin
   S, x = polynomial_ring(residue_ring(ZZ, 1009*2003)[1], "x")

   for dim = 0:5
      R = matrix_space(S, dim, dim)

      M = rand(R, -1:5, -100:100)

      @test det(M) == AbstractAlgebra.det_clow(M)
   end

   S, z = polynomial_ring(ZZ, "z")

   for dim = 0:5
      R = matrix_space(S, dim, dim)

      M = rand(R, -1:3, -20:20)

      @test det(M) == AbstractAlgebra.det_clow(M)
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)

   for dim = 0:7
      S = matrix_space(K, dim, dim)

      M = rand(S, -100:100)

      @test det(M) == AbstractAlgebra.det_clow(M)
   end

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")

   for dim = 0:5
      T = matrix_space(S, dim, dim)
      M = rand(T, 0:2, -1:2, -10:10)

      @test det(M) == AbstractAlgebra.det_clow(M)
   end
end

@testset "Generic.Mat.minors" begin
   S, z = polynomial_ring(ZZ,"z")
   n = 5
   R = matrix_space(S, n, n)
   for r = 0:n
      M = randmat_with_rank(R, r, 0:3, 0:3)
      @test [1] == minors(M, 0)
      for i = r + 1:n
         for m in minors(M, i)
            @test m == 0
         end
      end
      @test [det(M)] == minors(M, n)
      @test [] == minors(M, n + 1)
      @test [(det(M),[i for i in 1:n],[j for j in 1:n])] == minors_with_position(M,n)
   end
end

@testset "Generic.Mat.exterior_power" begin
   S, z = polynomial_ring(ZZ,"z")
   n = 5
   A = matrix(S, 3, 3, [1, 2, 3, 4, 5, 6, 7, 8, 9])
   @test exterior_power(A, 3) == diagonal_matrix(det(A), 1)
   @test exterior_power(A, 1) == A
   @test exterior_power(A, 2) == S[-3 -6 -3;
                                   -6 -12 -6;
                                   -3 -6 -3]
end

@testset "Generic.Mat.pfaffian" begin
   n = 5
   R, x = polynomial_ring(QQ, ["x$i" for i in 1:binomial(n, 2)])
   pf = [R(1), R(), x[1], R(), x[1]*x[6] - x[2]*x[5] + x[3]*x[4], R()]
   for dim in 0:5
      idx = 0
      M = matrix(R, [j <= i ? R() : (idx += 1; x[idx]) for j in 1:dim, i in 1:dim])
      if dim >= 2 # the matrix is indeed skew-symmetric when dim <= 1
         @test_throws DomainError pfaffian(M)
      end
      M = transpose(M) - M
      @test pf[dim + 1] == AbstractAlgebra.pfaffian_r(M)
      @test pf[dim + 1] == AbstractAlgebra.pfaffian_bfl(M)
      @test pf[dim + 1] == AbstractAlgebra.pfaffian_bfl_bsgs(M)
   end

   # do a big matrix which uses BFL
   R = matrix_space(QQ, 12, 12)
   M = rand(R, -5:5)
   M = transpose(M) - M
   @test det(M) == pfaffian(M)^2
   
   S, z = polynomial_ring(ZZ, "z")
   n = 5
   for dim = 0:n
      R = matrix_space(S, dim, dim)
      M = rand(R, -1:5, -5:5)
      M = transpose(M) - M
      @test [1] == pfaffians(M, 0)
      for i = 1:2:dim
         for m in pfaffians(M, i)
            @test m == 0
         end
      end
      @test det(M) == pfaffian(M)^2
      @test det(M) == pfaffians(M, dim)[1]^2
      @test [] == pfaffians(M, dim + 1)
   end
end

@testset "Generic.Mat.rank" begin
   S, = residue_ring(ZZ, 20011*10007)
   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -100:100)
      do_test = false
      r = 0

      try
         r = rank(M)
         do_test = true
      catch e
         if !(e isa ErrorException)
            rethrow(e)
         end
      end

      if do_test
         @test r == i
      end
   end

   S, z = polynomial_ring(ZZ, "z")
   R = matrix_space(S, 4, 4)

   M = R([S(-2) S(0) S(5) S(3); 5*z^2+5*z-5 S(0) S(-z^2+z) 5*z^2+5*z+1; 2*z-1 S(0) z^2+3*z+2 S(-4*z); 3*z-5 S(0) S(-5*z+5) S(1)])

   @test rank(M) == 3

   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -1:3, -20:20)

      @test rank(M) == i
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 3, 3)

   M = S([a a^2 + 2*a - 1 2*a^2 - 1*a; 2*a+2 2*a^2 + 2*a (-2*a^2 - 2*a); (-a) (-a^2) a^2])

   @test rank(M) == 2

   S = matrix_space(K, 5, 5)

   for i = 0:5
      M = randmat_with_rank(S, i, -100:100)

      @test rank(M) == i
   end

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")
   T = matrix_space(S, 3, 3)

   M = T([(2*x^2)*y^2+(-2*x^2-2*x)*y+(-x^2+2*x) S(0) (-x^2-2)*y^2+(x^2+2*x+2)*y+(2*x^2-x-1);
    (-x)*y^2+(-x^2+x-1)*y+(x^2-2*x+2) S(0) (2*x^2+x-1)*y^2+(-2*x^2-2*x-2)*y+(x^2-x);
    (-x+2)*y^2+(x^2+x+1)*y+(-x^2+x-1) S(0) (-x^2-x+2)*y^2+(-x-1)*y+(-x-1)])

   @test rank(M) == 2

   T = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(T, i, 0:2, -1:2, -20:20)

      @test rank(M) == i
   end
end

@testset "Generic.Mat._can_solve_with_solution_fflu" begin
   R = ZZ

   # Test random soluble systems
   for i = 1:100
      m = rand(0:30)
      n = rand(0:30)
      k = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank, -20:20)
      if n > 0 && rand(0:1) == 0
         col = rand(1:n)
         for i = 1:m
            A[i, col] = 0
         end
      end
      X2 = rand(U, -20:20)
      B = A*X2
      d2 = R()
      while iszero(d2)
         d2 = rand(R, -20:20)
      end
      A *= d2
      flag, X, d = Generic._can_solve_with_solution_fflu(A, B)
      @test flag && A*X == B*d
      B = rand(T, -10:10)
      flag, X, d = Generic._can_solve_with_solution_fflu(A, B)
      @test (flag && A*X == B*d) || !flag
   end

   # Test random systems (most will be insoluble)
   for i = 1:100
      m = rand(0:30)
      n = rand(0:30)
      k = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank, -20:20)
      B = rand(T, -20:20)
      flag1, X, d = Generic._can_solve_with_solution_fflu(A, B)
      A2 = change_base_ring(QQ, A)
      B2 = change_base_ring(QQ, B)
      flag2, X2 = can_solve_with_solution(A2, B2, side = :right)
      @test flag1 == flag2
   end
end

@testset "Generic.Mat.can_solve_with_solution_lu" begin
   R = GF(17)

   for i = 1:100
      m = rand(0:30)
      n = rand(0:30)
      k = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank)
      # randomly zero a column
      if n > 0 && rand(0:1) == 0
         col = rand(1:n)
         for i = 1:m
            A[i, col] = 0
         end
      end
      X2 = rand(U)
      B = A*X2
      flag, X = Generic._can_solve_with_solution_lu(A, B)
      @test flag && A*X == B
      B = rand(T)
      flag, X = Generic._can_solve_with_solution_lu(A, B)
      @test (flag && A*X == B) || !flag
   end

   R = QQ

   for i = 1:50
       m = rand(0:30)
       n = rand(0:30)
       k = rand(0:30)
       rank = rand(0:min(m, n))
       S = matrix_space(R, m, n)
       T = matrix_space(R, m, k)
       U = matrix_space(R, n, k)
       A = randmat_with_rank(S, rank, -20:20)
       X2 = rand(U, -20:20)
       B = A*X2
       flag, X = Generic._can_solve_with_solution_lu(A, B)
       @test flag && A*X == B
    end

   for dim = 0:5
      S = matrix_space(R, dim, dim)
      U = matrix_space(R, dim, rand(1:5))

      M = randmat_with_rank(S, dim, -100:100)
      b = rand(U, -100:100)

      flag, x = Generic._can_solve_with_solution_lu(M, b)

      @test flag && M*x == b
   end

   S, y = polynomial_ring(ZZ, "y")
   K = fraction_field(S)

   for dim = 0:5
      R = matrix_space(S, dim, dim)
      U = matrix_space(S, dim, rand(1:5))

      M = randmat_with_rank(R, dim, -1:5, -100:100)
      b = rand(U, 0:5, -100:100);

      MK = matrix(K, elem_type(K)[ K(M[i, j]) for i in 1:nrows(M), j in 1:ncols(M) ])
      bK = matrix(K, elem_type(K)[ K(b[i, j]) for i in 1:nrows(b), j in 1:ncols(b) ])

      flag, x = Generic._can_solve_with_solution_lu(MK, bK)

      @test flag && MK*x == bK
   end
end

@testset "Generic.Mat._solve_ff" begin
   # Exact field
   R = QQ

   for i = 1:50
      m = rand(0:20)
      n = rand(0:20)
      k = rand(0:20)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank, -10:10)
      X2 = rand(U, -10:10)
      B = A*X2
      d = R()
      while iszero(d)
         d = rand(R, -10:10)
      end
      B = divexact(B, d)
      @test A*divexact(X2, d) == B
      X = AbstractAlgebra._solve_ff(A, B)
      @test A*X == B
   end

   # Exact ring
   R = ZZ

   # Test random soluble systems
   for i = 1:100
      m = rand(0:30)
      n = rand(0:30)
      k = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank, -20:20)
      X2 = rand(U, -20:20)
      B = A*X2
      X, d = AbstractAlgebra._solve_ff(A, B)
      @test A*X == B*d
   end
end

@testset "Generic.Mat._solve_rational" begin
   R = ZZ

   for i = 1:100
      m = rand(0:30)
      n = rand(0:30)
      k = rand(0:30)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, m, k)
      U = matrix_space(R, n, k)
      A = randmat_with_rank(S, rank, -20:20)
      X2 = rand(U, -20:20)
      B = A*X2
      X, d = AbstractAlgebra._solve_rational(A, B)
      @test A*X == B*d
   end

   S, = residue_ring(ZZ, 20011*10007)

   for dim = 0:5
      R = matrix_space(S, dim, dim)
      U = matrix_space(S, dim, rand(1:5))

      M = randmat_with_rank(R, dim, -100:100)
      b = rand(U, -100:100)

      do_test = false
      try
         x, d = AbstractAlgebra._solve_rational(M, b)
         do_test = true
      catch e
         if !(e isa ErrorException)
             rethrow(e)
         end
      end

      if do_test
         @test M*x == d*b
      end
   end

   S, z = polynomial_ring(ZZ, "z")

   for iters = 1:100
      m = rand(0:5)
      n = rand(0:5)
      k = rand(0:5)
      R = matrix_space(S, m, n)
      U = matrix_space(S, n, k)
      rnk = rand(0:min(m, n))
      M = randmat_with_rank(R, rnk, -1:3, -20:20)
      x2 = rand(U, 0:3, -20:20)
      d2 = S()
      while iszero(d2)
         d2 = rand(S, 0:3, -20:20)
      end
      M *= d2
      b = M*x2
      x, d = AbstractAlgebra._solve_rational(M, b)

      @test M*x == d*b
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)

   for dim = 0:5
      S = matrix_space(K, dim, dim)
      U = matrix_space(K, dim, rand(1:5))

      M = randmat_with_rank(S, dim, -100:100)
      b = rand(U, -100:100)

      x = solve(M, b, side = :right)

      @test M*x == b
   end

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")

   for iters = 1:30
      m = rand(0:5)
      n = rand(0:5)
      k = rand(0:5)
      R = matrix_space(S, m, n)
      U = matrix_space(S, n, k)
      rnk = rand(0:min(m, n))
      M = randmat_with_rank(R, rnk, 0:2, -1:2, -20:20)
      x2 = rand(U, 0:2, -1:2, -20:20)
      d2 = zero(S)
      while iszero(d2)
         d2 = rand(S, 0:2, -1:2, -20:20)
      end
      M *= d2
      b = M*x2
      x, d = AbstractAlgebra._solve_rational(M, b)

      @test M*x == d*b
   end

   R, x = polynomial_ring(AbstractAlgebra.JuliaQQ, "t")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)

   S, y = polynomial_ring(K, "y")
   T = matrix_space(S, 3, 3)
   U = matrix_space(S, 3, 1)

   M = T([3y*a^2 + (y + 1)*a + 2y (5y+1)*a^2 + 2a + y - 1 a^2 + (-a) + 2y; (y + 1)*a^2 + 2y - 4 3y*a^2 + (2y - 1)*a + y (4y - 1)*a^2 + (y - 1)*a + 5; 2a + y + 1 (2y + 2)*a^2 + 3y*a + 3y a^2 + (-y-1)*a + (-y - 3)])
   b = U(permutedims([4y*a^2 + 4y*a + 2y + 1 5y*a^2 + (2y + 1)*a + 6y + 1 (y + 1)*a^2 + 3y*a + 2y + 4]))

   x, d = AbstractAlgebra._solve_rational(M, b)

   @test M*x == d*b
end

@testset "Generic.Mat.solve_right" begin
   for R in [ZZ, QQ]
      for iter = 1:40
         for dim = 0:5
            r = rand(1:5)
            n = rand(1:5)
            c = rand(1:5)

            S = matrix_space(R, r, n)
            U = matrix_space(R, n, c)

            X1 = rand(U, -20:20)
            M = rand(S, -20:20)

            B = M*X1
            X = solve(M, B, side = :right)

            @test M*X == B
         end
      end
   end
   R, x = polynomial_ring(QQ, "x")

   for iter = 1:4
      for dim = 0:5
         r = rand(1:5)
         n = rand(1:5)
         c = rand(1:5)

         S = matrix_space(R, r, n)
         U = matrix_space(R, n, c)

         X1 = rand(U, -1:2, -10:10)
         M = rand(S, -1:2, -10:10)

         B = M*X1
         X = solve(M, B, side = :right)

         @test M*X == B
      end
   end
end

@testset "Generic.Mat.solve_left" begin
   for R in [ZZ, QQ]
      for iter = 1:40
         for dim = 0:5
            r = rand(1:5)
            n = rand(1:5)
            c = rand(1:5)

            S = matrix_space(R, r, n)
            U = matrix_space(R, n, c)

            X1 = rand(S, -20:20)
            M = rand(U, -20:20)

            B = X1*M
            X = solve(M, X1*M)

            @test X*M == B
         end
      end
   end

   R, x = polynomial_ring(QQ, "x")

   for iter = 1:4
      for dim = 0:5
         r = rand(1:5)
         n = rand(1:5)
         c = rand(1:5)

         S = matrix_space(R, r, n)
         U = matrix_space(R, n, c)

         X1 = rand(S, -1:2, -10:10)
         M = rand(U, -1:2, -10:10)

         B = X1*M
         X = solve(M, X1*M)

         @test X*M == B
      end
   end
end

@testset "Generic.Mat.can_solve" begin
   R, x = polynomial_ring(QQ, "x")
   S = fraction_field(R)

   for iter = 1:8
      m = rand(0:7)

      T = matrix_space(R, m, m)
      U = matrix_space(R, m, m)

      M = rand(T, -1:2, -10:10)
      X2 = rand(U, -1:2, -10:10)
      b = M*X2

      flag, X = can_solve_with_solution(M, b, side = :right)

      @test flag && M*X == b

      b = X2*M

      flag, X = can_solve_with_solution(M, b)

      @test flag && X*M == b
   end

   R, x = polynomial_ring(GF(65537), "x")
   S = fraction_field(R)

   for iters = 1:10
      m = rand(1:15)
      T = matrix_space(R, m, m)
      U = matrix_space(R, m, m)

      M = rand(T, 0:2)
      X2 = rand(U, 0:2)
      b = M*X2

      M = change_base_ring(S, M)
      b = change_base_ring(S, b)

      flag, X = can_solve_with_solution(M, b, side = :right)

      @test flag && M*X == b

      M = rand(T, 0:2)
      X2 = rand(U, 0:2)
      b = X2*M

      M = change_base_ring(S, M)
      b = change_base_ring(S, b)

      flag, X = can_solve_with_solution(M, b)

      @test flag && X*M == b
   end

   for R in [ZZ, QQ]
      for iter = 1:40
         for dim = 0:5
            r = rand(1:5)
            n = rand(1:5)
            c = rand(1:5)

            let
               S = matrix_space(R, n, r)
               U = matrix_space(R, c, n)

               X1 = rand(S, -20:20)
               M = rand(U, -20:20)

               B = M*X1
               (flag, X) = can_solve_with_solution(M, M*X1, side = :right)

               @test can_solve(M, B, side = :right)
               @test flag && M*X == B
            end

            let
               S = matrix_space(R, r, n)
               U = matrix_space(R, n, c)

               X1 = rand(S, -20:20)
               M = rand(U, -20:20)

               B = X1*M
               (flag, X) = can_solve_with_solution(M, X1*M)

               @test can_solve(M, B)
               @test flag && X*M == B
            end
         end
      end
   end

   R, x = polynomial_ring(QQ, "x")

   for iter = 1:4
      for dim = 0:5
         r = rand(1:5)
         n = rand(1:5)
         c = rand(1:5)

         let
            S = matrix_space(R, n, r)
            U = matrix_space(R, c, n)

            X1 = rand(S, -1:2, -10:10)
            M = rand(U, -1:2, -10:10)

            B = M*X1
            (flag, X) = can_solve_with_solution(M, M*X1, side = :right)

            @test can_solve(M, B, side = :right)
            @test flag && M*X == B

            (flag, X) = can_solve_with_solution(M, M*X1, side = :right)

            @test can_solve(M, B, side = :right)
            @test flag && M*X == B
         end

         let
            S = matrix_space(R, r, n)
            U = matrix_space(R, n, c)

            X1 = rand(S, -1:2, -10:10)
            M = rand(U, -1:2, -10:10)

            B = X1*M
            (flag, X) = can_solve_with_solution(M, X1*M)

            @test can_solve(M, B)
            @test flag && X*M == B
         end
      end
   end

   let
      M = matrix(R, 1, 1, [x])
      X = matrix(R, 1, 1, [1])

      @assert !can_solve(M, X, side = :right)
      (flag, _) = can_solve_with_solution(M, X, side = :right)
      @assert !flag

      @assert !can_solve(M, X)
      (flag, _) = can_solve_with_solution(M, X)
      @assert !flag
   end

   let
      M = matrix(ZZ, 2, 2, [1, 1, 1, 1])
      X = matrix(ZZ, 2, 1, [1, 0])

      @assert !can_solve(M, X, side = :right)
      (flag, _) = can_solve_with_solution(M, X, side = :right)
      @assert !flag

      @assert !can_solve(M, transpose(X))
      (flag, _) = can_solve_with_solution(M, transpose(X))
      @assert !flag
   end

   let
      M = matrix(ZZ, 3, 3, [2, 0, 0, 0, 1, 0, 0, 0, 1])

      X1 = matrix(ZZ, 3, 1, [1, 0, 0])
      @assert !can_solve(M, X1, side = :right)
      (flag, X) = can_solve_with_solution(M, X1, side = :right)
      @assert !flag

      X2 = matrix(ZZ, 2, 3, [1, 0, 0, 0, 1, 0])
      @assert !can_solve(M, X2)
      (flag, _) = can_solve_with_solution(M, X2)
      @assert !flag
   end

   @test_throws Exception can_solve_with_solution(matrix(ZZ, 2, 2, [1, 0, 0, 1]), matrix(ZZ, 2, 1, [2, 3]), side = :aaa)
   @test_throws TypeError can_solve_with_solution(matrix(ZZ, 2, 2, [1, 0, 0, 1]), matrix(ZZ, 2, 1, [2, 3]), side = "right")
end

@testset "Generic.Mat.can_solve_with_solution_interpolation" begin
   R1, = residue_ring(ZZ, 65537)
   R, x = polynomial_ring(R1, "x")
   RZ, x = polynomial_ring(ZZ, "x")

   for iters = 1:50
      m = rand(0:10)
      n = rand(0:10)
      k = rand(0:10)
      rnk = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      T = matrix_space(R, n, k)
      U = matrix_space(R, m, k)

      S1 = matrix_space(RZ, m, n)
      MZ = randmat_with_rank(S1, rnk, 0:2, -20:20)

      M = matrix(R, m, n, [change_base_ring(R1, MZ[i, j]) for i in 1:m for j in 1:n])
      K = fraction_field(R)
      MK = change_base_ring(K, M)
      X2 = rand(T, -1:2, 0:65536)
      B = M*X2
      d2 = R()
      while iszero(d2)
         d2 = rand(R, -1:2, 0:65536);
      end
      M = M*d2

      flag, X, d = AbstractAlgebra._can_solve_with_solution_interpolation(M, B)

      @test flag && M*X == B*d
   end
end

@testset "Generic.Mat._solve_triu" begin
   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)

   for dim = 0:10
      S = matrix_space(K, dim, dim)
      U = matrix_space(K, dim, rand(1:5))

      M = randmat_triu(S, -100:100)
      b = rand(U, -100:100)

      x = AbstractAlgebra._solve_triu(M, b; unipotent = false, side = :right)

      @test M*x == b
   end
end

@testset "Generic.Mat.rref" begin
   # Non-integral domain

   S, = residue_ring(ZZ, 20011*10007)
   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -100:100)

      do_test = false
      r = 0
      d = S(0)
      A = M

      try
          r, A, d = rref_rational(M)
          do_test = true
      catch e
         if !(e isa ErrorException)
            rethrow(e)
         end
      end

      if do_test
         @test r == i
         @test is_rref(A)
      end
   end

   # Exact ring

   R = ZZ

   for iters = 1:50
      m = rand(0:50)
      n = rand(0:50)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      M = randmat_with_rank(S, rank, -10:10)
      r, N, d = rref_rational(M)

      @test r == rank
      @test is_rref(N)

      N2 = change_base_ring(QQ, N)
      N2 = divexact(N2, d)

      @test is_rref(N2)
   end


   S, z = polynomial_ring(ZZ, "z")
   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -1:3, -20:20)

      r, A, d = rref_rational(M)

      @test r == i
      @test is_rref(A)
   end

   # Exact field

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 5, 5)

   for i = 0:5
      M = randmat_with_rank(S, i, -100:100)

      r, A = rref(M)

      @test r == i
      @test is_rref(A)
   end

   R = GF(7)

   for iters = 1:50
      m = rand(0:50)
      n = rand(0:50)
      rank = rand(0:min(m, n))
      S = matrix_space(R, m, n)
      M = randmat_with_rank(S, rank)
      r, N = rref(M)

      @test r == rank
      @test is_rref(N)
   end

   # Multiple level exact ring

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")
   T = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(T, i, 0:2, -1:2, -20:20)

      r, A, d = rref_rational(M)

      @test r == i
      @test is_rref(A)
   end
end

@testset "Generic.Mat.is_invertible" begin
   R, x = polynomial_ring(QQ, "x")

   let
      M = matrix(R, 1, 1, [R(1)])

      @test is_invertible(M)
      (flag, _) = is_invertible_with_inverse(M)
      @test flag
      (flag, _) = is_invertible_with_inverse(M; side = :right)
      @test flag
   end

   let
      M = matrix(R, 1, 1, [x])

      @test !is_invertible(M)
      (flag, _) = is_invertible_with_inverse(M)
      @test !flag
      (flag, _) = is_invertible_with_inverse(M; side = :right)
      @test !flag
   end

   let
      M = matrix(ZZ, 2, 2, [1, 1, 1, 1])

      @test !is_invertible(M)
      (flag, _) = is_invertible_with_inverse(M)
      @test !flag
      (flag, _) = is_invertible_with_inverse(M; side = :right)
      @test !flag
   end

   let
      M = matrix(QQ, 4, 4, [1, 1, 1, 1, 1, -1, 1, -1, 1, 1, -1, -1, 1, -1, -1, 1])

      @test is_invertible(M)
      (flag, _) = is_invertible_with_inverse(M)
      @test flag
      (flag, _) = is_invertible_with_inverse(M; side = :right)
      @test flag
   end

   let
      M = matrix(QQ, 3, 3, [1, 2, 3, 4, 5, 6, 7, 8, 0])

      @test is_invertible(M)
      (flag, _) = is_invertible_with_inverse(M)
      @test flag
      (flag, _) = is_invertible_with_inverse(M; side = :right)
      @test flag
   end

   for _ in 1:100
      m = rand(1:10)
      n = rand(m:10)
      M1 = matrix_space(QQ, n, m)
      M2 = matrix_space(QQ, m, n)

      L_l = randmat_with_rank(M1, m, -10:10)
      L_r = randmat_with_rank(M2, m, -10:10)

      I_m = matrix(QQ, m, m, [i == j ? 1 : 0 for i in 1:m, j in 1:m])

      (flag_l, x_l) = is_invertible_with_inverse(L_l; side = :left)
      @test flag_l && x_l * L_l == I_m
      (flag_r, x_r) = is_invertible_with_inverse(L_r; side = :right)
      @test flag_r && L_r * x_r == I_m
   end

   for _ in 1:100
      n = rand(1:10)
      M = matrix_space(QQ, n, n)

      L = randmat_with_rank(M, rand(0:n-1), -10:10)

      @test !is_invertible(L)
      (flag, _) = is_invertible_with_inverse(L; side = :left)
      @test !flag
      (flag, _) = is_invertible_with_inverse(L; side = :right)
      @test !flag
   end
end

@testset "Generic.Mat.nullspace" begin
   S, = residue_ring(ZZ, 20011*10007)
   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -100:100)

      do_test = false
      n = 0
      N = M
      r = 0

      try
         n, N = nullspace(M)
         r = rank(N)
         do_test = true
      catch e
         if !(e isa ErrorException)
            rethrow(e)
         end
      end

      if do_test
         @test n == 5 - i
         @test r == n
         @test iszero(M*N)
      end
   end

   S, z = polynomial_ring(ZZ, "z")
   R = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -1:3, -20:20)

      n, N = nullspace(M)

      @test n == 5 - i
      @test rank(N) == n
      @test iszero(M*N)
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 5, 5)

   for i = 0:5
      M = randmat_with_rank(S, i, -100:100)

      n, N = nullspace(M)

      @test n == 5 - i
      @test rank(N) == n
      @test iszero(M*N)
   end

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")
   T = matrix_space(S, 5, 5)

   for i = 0:5
      M = randmat_with_rank(T, i, 0:2, -1:2, -20:20)

      n, N = nullspace(M)

      @test n == 5 - i
      @test rank(N) == n
      @test iszero(M*N)
   end
end

@testset "Generic.Mat.kernel" begin
   R = matrix_space(ZZ, 5, 5)

   for i = 0:5
      M = randmat_with_rank(R, i, -20:20)

      N = AbstractAlgebra.kernel(M, side = :right)

      @test ncols(N) == 5 - i
      @test rank(N) == ncols(N)
      @test iszero(M*N)

      N = AbstractAlgebra.kernel(M)

      @test nrows(N) == 5 - i
      @test rank(N) == nrows(N)
      @test iszero(N*M)
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)
   S = matrix_space(K, 5, 5)

   for i = 0:5
      M = randmat_with_rank(S, i, -100:100)

      N = AbstractAlgebra.kernel(M, side = :right)

      @test ncols(N) == 5 - i
      @test rank(N) == ncols(N)
      @test iszero(M*N)

      N = AbstractAlgebra.kernel(M)

      @test nrows(N) == 5 - i
      @test rank(N) == nrows(N)
      @test iszero(N*M)
   end

   R, x = polynomial_ring(QQ, "x")
   T = matrix_space(R, 5, 5)

   for i = 0:5
      M = randmat_with_rank(T, i, -1:2, -20:20)

      N = AbstractAlgebra.kernel(M, side = :right)

      @test ncols(N) == 5 - i
      @test rank(N) == ncols(N)
      @test iszero(M*N)

      N = AbstractAlgebra.kernel(M)

      @test nrows(N) == 5 - i
      @test rank(N) == nrows(N)
      @test iszero(N*M)
   end
end

@testset "Generic.Mat.can_solve_with_solution_and_kernel" begin
   # Exact Ring, Exact field

   for F in [ZZ, QQ]
      for iters = 1:1000
         m = rand(0:10)
         n = rand(0:10)
         k = rand(0:10)

         R = matrix_space(F, m, n)
         S = matrix_space(F, m, k)
         U = matrix_space(F, n, k)

         # random with solution
         r = rand(0:min(m, n))
         M = randmat_with_rank(R, r, -20:20)
         X = rand(U, -20:20)

         B = M*X

         flag, Sol, K = can_solve_with_solution_and_kernel(M, B, side = :right)

         @test iszero(M*K)
         @test flag && M*Sol == B

         # fully random
         B = rand(S, -20:20)

         flag, Sol, K = can_solve_with_solution_and_kernel(M, B, side = :right)
         flag2, Sol2 = can_solve_with_solution(M, B, side = :right)

         @test flag == flag2
         if flag
            @test M*Sol == B
            @test iszero(M*K)

            N = AbstractAlgebra.kernel(M, side = :right)
            @test nrows(N) == nrows(K)
            @test ncols(N) == ncols(K)
         end

         # left kernel, random with solution
         r = rand(0:min(n, k))
         M = randmat_with_rank(U, r, -20:20)
         X = rand(R, -20:20)

         B = X*M

         flag, Sol, K = can_solve_with_solution_and_kernel(M, B)

         @test iszero(K*M)
         @test flag && Sol*M == B
      end
   end
end

@testset "Generic.Mat.inversion" begin
   for dim = 2:5
      R = matrix_space(ZZ, dim, dim)
      M = R(1)
      i = rand(1:dim-1)
      j = rand(i+1:dim)
      M[i,j] = 1 # E_{i,j} elementary matrix

      N, c = pseudo_inv(M)
      @test N isa elem_type(R)
      @test c isa eltype(M)

      @test is_unit(c)
      @test N[i,j] == -1
      @test M*N == N*M == c*R(1)

      M[j,i] = -1
      NN, cc = pseudo_inv(M)
      @test NN[i,j] == -1
      @test NN[j,i] == 1

      @test M*NN == NN*M == cc*R(1)
   end

   S, = residue_ring(ZZ, 20011*10007)

   for dim = 1:5
      R = matrix_space(S, dim, dim)

      M = randmat_with_rank(R, dim, -100:100)

      do_test = false
      X = M
      d = R(0)

      try
          X, d = pseudo_inv(M)
          do_test = true
      catch e
         if !(e isa ErrorException)
            rethrow(e)
         end
      end

      if do_test
         @test M*X == d*one(R)
      end
   end

   S, z = polynomial_ring(ZZ, "z")

   for dim = 1:5
      R = matrix_space(S, dim, dim)

      M = randmat_with_rank(R, dim, -1:3, -20:20)

      X, d = pseudo_inv(M)

      @test M*X == d*one(R)
   end

   R, x = polynomial_ring(QQ, "x")
   K, = residue_field(R, x^3 + 3x + 1)
   a = K(x)

   for dim = 1:5
      S = matrix_space(K, dim, dim)

      M = randmat_with_rank(S, dim, -100:100)

      X, d = pseudo_inv(M)

      @test M*X == d*one(S)
   end

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")

   for dim = 1:5
      T = matrix_space(S, dim, dim)

      M = randmat_with_rank(T, dim, 0:2, -1:2, -20:20)

      X, d = pseudo_inv(M)

      @test M*X == d*one(T)
   end

   # inv should preserve the type of the input
   M = matrix(F2(), F2Elem[1 0; 0 1])
   @test typeof(inv(M))   == typeof(M)
   @test typeof(inv(M.m)) == typeof(M.m)
end

@testset "Generic.Mat.hessenberg" begin
   R, = residue_ring(ZZ, 18446744073709551629)

   for dim = 0:5
      S = matrix_space(R, dim, dim)
      U, x = polynomial_ring(R, "x")

      for i = 1:10
         M = rand(S, -5:5)

         A = hessenberg(M)

         @test is_hessenberg(A)
      end
   end

   M = matrix(ZZ, 3, 3, [10 -4 8; -1 -5 -3; 3 8 -10])
   H = hessenberg(M)

   @test H == matrix(ZZ, 3, 3, [10 -28 8; -1 4 -3; 0 50 -19])
end

@testset "Generic.Mat.kronecker_product" begin
   R, = residue_ring(ZZ, 18446744073709551629)
   S = matrix_space(R, 2, 3)
   S2 = matrix_space(R, 2, 2)
   S3 = matrix_space(R, 3, 3)

   A = S(R.([2 3 5; 9 6 3]))
   B = S2(R.([2 3; 1 4]))
   C = S3(R.([2 3 5; 1 4 7; 9 6 3]))

   @test size(kronecker_product(A, A)) == (4,9)
   @test kronecker_product(B*A,A*C) == kronecker_product(B,A) * kronecker_product(A,C)
end

@testset "Generic.Mat.charpoly" begin
   R, = residue_ring(ZZ, 18446744073709551629)

   for dim = 0:5
      S = matrix_space(R, dim, dim)
      U, x = polynomial_ring(R, "x")

      for i = 1:10
         M = rand(S, -5:5)

         p1 = charpoly(U, M)
         p2 = charpoly_danilevsky!(U, M)

         @test p1 == p2
      end

      for i = 1:10
         M = rand(S, -5:5)

         p1 = charpoly(U, M)
         p2 = charpoly_danilevsky_ff!(U, M)

         @test p1 == p2
      end

      for i = 1:10
         M = rand(S, -5:5)

         p1 = charpoly(U, M)
         p2 = charpoly_hessenberg!(U, M)

         @test p1 == p2
      end
   end

   R, x = polynomial_ring(ZZ, "x")
   U, z = polynomial_ring(R, "z")
   T = matrix_space(R, 6, 6)

   M = T()
   for i = 1:3
      for j = 1:3
         M[i, j] = rand(R, -1:2, -10:10)
         M[i + 3, j + 3] = deepcopy(M[i, j])
      end
   end

   p1 = charpoly(U, M)

   for i = 1:10
      similarity!(M, rand(1:6), R(rand(R, -1:2, -3:3)))
   end

   p2 = charpoly(U, M)

   @test p1 == p2
end

@testset "Generic.Mat.minpoly" begin
   R = GF(103)
   T, y = polynomial_ring(R, "y")

   M = R[92 97 8;
          0 5 13;
          0 16 2]

   @test minpoly(T, M) == y^2+96*y+8

   R = GF(3)
   T, y = polynomial_ring(R, "y")

   M = R[1 2 0 2;
         1 2 1 0;
         1 2 2 1;
         2 1 2 0]

   @test minpoly(T, M) == y^2 + 2y

   R = GF(13)
   T, y = polynomial_ring(R, "y")

   M = R[7 6 1;
         7 7 5;
         8 12 5]

   @test minpoly(T, M) == y^2+10*y

   M = R[4 0 9 5;
         1 0 1 9;
         0 0 7 6;
         0 0 3 10]

   @test minpoly(T, M) == y^2 + 9y

   M = R[2 7 0 0 0 0;
         1 0 0 0 0 0;
         0 0 2 7 0 0;
         0 0 1 0 0 0;
         0 0 0 0 4 3;
         0 0 0 0 1 0]

   @test minpoly(T, M) == (y^2+9*y+10)*(y^2+11*y+6)

   M = R[2 7 0 0 0 0;
         1 0 1 0 0 0;
         0 0 2 7 0 0;
         0 0 1 0 0 0;
         0 0 0 0 4 3;
         0 0 0 0 1 0]

   @test minpoly(T, M) == (y^2+9*y+10)*(y^2+11*y+6)^2

   S = matrix_space(R, 1, 1)
   M = S()

   @test minpoly(T, M) == y

   S = matrix_space(R, 0, 0)
   M = S()

   @test minpoly(T, M) == 1

   R, x = polynomial_ring(ZZ, "x")
   S, y = polynomial_ring(R, "y")
   U, z = polynomial_ring(S, "z")
   T = matrix_space(S, 6, 6)

   M = T()
   for i = 1:3
      for j = 1:3
         M[i, j] = rand(S, 0:3, -1:3, -10:10)
         M[i + 3, j + 3] = deepcopy(M[i, j])
      end
   end

   f = minpoly(U, M)

   @test degree(f) <= 3

   R, x = polynomial_ring(ZZ, "x")
   U, z = polynomial_ring(R, "z")
   T = matrix_space(R, 6, 6)

   M = T()
   for i = 1:3
      for j = 1:3
         M[i, j] = rand(R, -1:2, -10:10)
         M[i + 3, j + 3] = deepcopy(M[i, j])
      end
   end

   p1 = minpoly(U, M)

   for i = 1:10
      similarity!(M, rand(1:6), R(rand(R, -1:2, -3:3)))
   end

   p2 = minpoly(U, M)

   @test p1 == p2
end

@testset "Generic.Mat.row_col_swapping" begin
   R, x = polynomial_ring(ZZ, "x")
   M = matrix_space(R, 3, 2)

   a = M(map(R, [1 2; 3 4; 5 6]))

   @test swap_rows(a, 1, 3) == M(map(R, [5 6; 3 4; 1 2]))

   swap_rows!(a, 2, 3)

   @test a == M(map(R, [1 2; 5 6; 3 4]))

   @test swap_cols(a, 1, 2) == matrix(R, [2 1; 6 5; 4 3])

   swap_cols!(a, 2, 1)

   @test a == matrix(R, [2 1; 6 5; 4 3])

   a = matrix(R, [1 2; 3 4])
   @test reverse_rows(a) == matrix(R, [3 4; 1 2])
   reverse_rows!(a)
   @test a == matrix(R, [3 4; 1 2])

   a = matrix(R, [1 2; 3 4])
   @test reverse_cols(a) == matrix(R, [2 1; 4 3])
   reverse_cols!(a)
   @test a == matrix(R, [2 1; 4 3])

   a = matrix(R, [1 2 3; 3 4 5; 5 6 7])

   @test reverse_rows(a) == matrix(R, [5 6 7; 3 4 5; 1 2 3])
   reverse_rows!(a)
   @test a == matrix(R, [5 6 7; 3 4 5; 1 2 3])

   a = matrix(R, [1 2 3; 3 4 5; 5 6 7])
   @test reverse_cols(a) == matrix(R, [3 2 1; 5 4 3; 7 6 5])
   reverse_cols!(a)
   @test a == matrix(R, [3 2 1; 5 4 3; 7 6 5])
end

@testset "Generic.Mat.gen_mat_elem_op" begin
   R, x = polynomial_ring(ZZ, "x")
   for i in 1:10
      r = rand(1:50)
      c = rand(1:50)
      S = matrix_space(R, r, c)
      M = rand(S, -1:3, -100:100)
      c1, c2 = rand(1:c), rand(1:c)
      s = rand(-100:100)
      r1 = rand(1:r)
      r2 = rand(r1:r)

      # add column

      # issue #755
      A = identity_matrix(ZZ, 2)
      A = add_column!(A, 2, 2, 1)
      @test isone(A[2, 2])

      N = add_column(M, s, c1, c2, r1:r2)
      for ci in 1:c
         if ci == c2
            @test all(N[k, c2] == M[k, c2] + s * M[k, c1] for k in r1:r2)
            @test all(N[k, c2] == M[k, c2] for k in 1:r if !(k in r1:r2))
         else
            @test all(N[k, ci] == M[k, ci] for k in 1:r)
         end
      end

      MM = deepcopy(M)
      add_column!(MM, s, c1, c2, r1:r2)
      for ci in 1:c
         if ci == c2
            @test all(MM[k, c2] == M[k, c2] + s * M[k, c1] for k in r1:r2)
            @test all(MM[k, c2] == M[k, c2] for k in 1:r if !(k in r1:r2))
         else
            @test all(MM[k, ci] == M[k, ci] for k in 1:r)
         end
      end

      if c1 != c2
         @test add_column(add_column(M, s, c1, c2), -s, c1, c2) == M
      end

      # multiply column

      # issue #755
      A = identity_matrix(ZZ, 2)
      A = multiply_column!(A, 2, 1)
      @test isone(A[2, 2])

      N = multiply_column(M, s, c1, r1:r2)
      for ci in 1:c
         if ci == c1
            @test all(N[k, c1] == s * M[k, c1] for k in r1:r2)
            @test all(N[k, c1] == M[k, c1] for k in 1:r if !(k in r1:r2))
         else
            @test all(N[k, ci] == M[k, ci] for k in 1:r)
         end
      end

      MM = deepcopy(M)
      multiply_column!(MM, s, c1, r1:r2)
      for ci in 1:c
         if ci == c1
            @test all(MM[k, c1] == s * M[k, c1] for k in r1:r2)
            @test all(MM[k, c1] == M[k, c1] for k in 1:r if !(k in r1:r2))
         else
            @test all(MM[k, ci] == M[k, ci] for k in 1:r)
         end
      end

      @test multiply_column(multiply_column(M, -one(R), c1), -one(R), c1) == M

      # add row

      # issue #755
      A = identity_matrix(ZZ, 2)
      A = add_row!(A, 2, 2, 1)
      @test isone(A[2, 2])

      r1, r2 = rand(1:r), rand(1:r)
      s = rand(-100:100)
      c1 = rand(1:c)
      c2 = rand(c1:c)

      N = add_row(M, s, r1, r2, c1:c2)
      for ci in 1:r
         if ci == r2
            @test all(N[r2, k] == M[r2, k] + s * M[r1, k] for k in c1:c2)
            @test all(N[r2, k] == M[r2, k] for k in 1:c if !(k in c1:c2))
         else
            @test all(N[ci, k] == M[ci, k] for k in 1:c)
         end
      end

      MM = deepcopy(M)
      add_row!(MM, s, r1, r2, c1:c2)
      for ci in 1:r
         if ci == r2
            @test all(MM[r2, k] == M[r2, k] + s * M[r1, k] for k in c1:c2)
            @test all(MM[r2, k] == M[r2, k] for k in 1:c if !(k in c1:c2))
         else
            @test all(MM[ci, k] == M[ci, k] for k in 1:c)
         end
      end

      if r1 != r2
         @test add_row(add_row(M, s, r1, r2), -s, r1, r2) == M
      end

      # multiply row

      # issue #755
      A = identity_matrix(ZZ, 2)
      A = multiply_row!(A, 2, 1)
      @test isone(A[2, 2])

      N = multiply_row(M, s, r1, c1:c2)
      for ci in 1:r
         if ci == r1
            @test all(N[r1, k] == s * M[r1, k] for k in c1:c2)
            @test all(N[r1, k] == M[r1, k] for k in 1:c if !(k in c1:c2))
         else
            @test all(N[ci, k] == M[ci, k] for k in 1:c)
         end
      end

      MM = deepcopy(M)
      multiply_row!(MM, s, r1, c1:c2)
      for ci in 1:r
         if ci == r1
            @test all(MM[r1, k] == s * M[r1, k] for k in c1:c2)
            @test all(MM[r1, k] == M[r1, k] for k in 1:c if !(k in c1:c2))
         else
            @test all(MM[ci, k] == M[ci, k] for k in 1:c)
         end
      end

      @test multiply_row(multiply_row(M, -one(R), r1), -one(R), r1) == M
   end
end

@testset "Generic.Mat.concat" begin
   R, x = polynomial_ring(ZZ, "x")

   for i = 1:10
      r = rand(0:10)
      c1 = rand(0:10)
      c2 = rand(0:10)

      S1 = matrix_space(R, r, c1)
      S2 = matrix_space(R, r, c2)

      M1 = rand(S1, -1:3, -100:100)
      M2 = rand(S2, -1:3, -100:100)

      @test vcat(transpose(M1), transpose(M2)) == transpose(hcat(M1, M2))
   end

   A = matrix(R, 2, 2, [1, 2, 3, 4])
   B = matrix(R, 4, 2, [1, 2, 3, 4, 0, 1, 0, 1])
   C = matrix(R, 4, 1, [0, 1, 0, 2])
   D = matrix(R, 2, 3, [1, 2, 3, 4, 5, 6])

   @test hcat(B, C) == matrix(R, [1 2 0;
                                  3 4 1;
                                  0 1 0;
                                  0 1 2;])
   @test hcat(B, C) == [B C]
   @test hcat(B, C, C, B) == reduce(hcat, [B, C, C, B])

   @test vcat(A, B) == matrix(R, [1 2;
                                  3 4;
                                  1 2;
                                  3 4;
                                  0 1;
                                  0 1;])

   @test vcat(A, B) == [A; B]
   @test vcat(A, B, B, A) == reduce(vcat, [A, B, B, A])

   @test [A D; B B C] == matrix(R, [1 2 1 2 3;
                                    3 4 4 5 6;
                                    1 2 1 2 0;
                                    3 4 3 4 1;
                                    0 1 0 1 0;
                                    0 1 0 1 2;])

   # Test constructors over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 2, 2)

   M = rand(S, -10:10)
   N = rand(S, -10:10)

   @test isa(hcat(M, N), MatElem)
   @test isa(vcat(M, N), MatElem)
   @test isa([M N; M N], MatElem)
end

@testset "Generic.Mat.hnf_minors" begin
   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   H = @inferred hnf_minors(A)
   @test is_hnf(H)

   H, U = @inferred hnf_minors_with_transform(A)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*A == H

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 4, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5; y 1 y 2]))

   H = @inferred hnf_minors(B)
   @test is_hnf(H)

   H, U = @inferred hnf_minors_with_transform(B)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*B == H
end

@testset "Generic.Mat.hnf_kb" begin
   M = matrix(ZZ, BigInt[4 6 2; 0 0 10; 0 5 3])

   H, U = @inferred AbstractAlgebra.hnf_kb_with_transform(M)

   @test H == matrix(ZZ, BigInt[4 1 9; 0 5 3; 0 0 10])
   @test is_unit(det(U))
   @test U*M == H

   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   H = @inferred AbstractAlgebra.hnf_kb(A)
   @test is_hnf(H)

   H, U = @inferred AbstractAlgebra.hnf_kb_with_transform(A)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*A == H

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 3, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5]))

   H = @inferred AbstractAlgebra.hnf_kb(B)
   @test is_hnf(H)

   H, U = @inferred AbstractAlgebra.hnf_kb_with_transform(B)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*B == H

   # hnf_kb! must not assume it "owns" entries of its input
   # A and B have de-aliased entries, a and b have aliased entries
   # the result must be the same
   A = R[1 1; 1 1]
   B = R[1 0; 0 1]
   # if any of the following assertions fail with a change to the code base,
   # find a new way to construct the matrices such that the assertions remain valid
   # (similar for snf_kb!)
   @assert length(IdDict(x => nothing for x in A.entries)) == 4
   @assert length(IdDict(x => nothing for x in B.entries)) == 4
   i = i0 = x^0
   z = z0 = 0*x
   a = R[i i; i i]
   b = R[i z; z i]
   @assert a[1, 1] === a[1, 2] === a[2, 1] === a[2, 2]
   @assert b[1, 1] === b[2, 2] &&  b[1, 2] === b[2, 1]
   Generic.hnf_kb!(A, B, true);
   Generic.hnf_kb!(a, b, true);
   @test i === i0 == x^0
   @test z === z0 == 0*x
   @test A == a
   @test B == b
end

@testset "Generic.Mat.hnf_cohen" begin
   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   H = AbstractAlgebra.hnf_cohen(A)
   @test is_hnf(H)

   H, U = AbstractAlgebra.hnf_cohen_with_transform(A)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*A == H

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 3, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5]))

   H = AbstractAlgebra.hnf_cohen(B)
   @test is_hnf(H)

   H, U = AbstractAlgebra.hnf_cohen_with_transform(B)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*B == H
end

@testset "Generic.Mat.hnf" begin
   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   H = hnf(A)
   @test is_hnf(H)

   H, U = hnf_with_transform(A)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*A == H

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 3, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5]))

   H = hnf(B)
   @test is_hnf(H)

   H, U = hnf_with_transform(B)
   @test is_hnf(H)
   @test is_unit(det(U))
   @test U*B == H
end

@testset "Generic.Mat.snf_kb" begin
   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   T = @inferred AbstractAlgebra.snf_kb(A)
   @test is_snf(T)

   T, U, K = @inferred AbstractAlgebra.snf_kb_with_transform(A)
   @test is_snf(T)
   @test is_unit(det(U))
   @test is_unit(det(K))
   @test U*A*K == T

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 3, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5]))

   T = @inferred AbstractAlgebra.snf_kb(B)
   @test is_snf(T)

   T, U, K = @inferred AbstractAlgebra.snf_kb_with_transform(B)
   @test is_snf(T)
   @test is_unit(det(U))
   @test is_unit(det(K))
   @test U*B*K == T

   # snf_kb! must not assume it "owns" entries of its input
   # A, B and C have de-aliased entries, a, b and c have aliased entries
   # the result must be the same
   A = R[1 1 0; 0 1 1]
   B = R[1 0; 0 1]
   C = R[1 0 0; 0 1 0; 0 0 1]
   @assert length(IdDict(x => nothing for x in A.entries)) == 6
   @assert length(IdDict(x => nothing for x in B.entries)) == 4
   i = i0 = x^0
   z = z0 = 0*x
   a = R[i i z; z i i]
   b = R[i z; z i]
   c = R[i z z; z i z; z z i]
   @assert a[1, 1] === a[1, 2] === a[2, 2] === a[2, 3]
   @assert b[1, 1] === b[2, 2] &&  b[1, 2] === b[2, 1]
   Generic.snf_kb!(A, B, C, true);
   Generic.snf_kb!(a, b, c, true);
   @test i === i0 == x^0
   @test z === z0 == 0*x
   @test A == a
   @test B == b
   @test C == c
end

@testset "Generic.Mat.snf" begin
   R, x = polynomial_ring(QQ, "x")

   M = matrix_space(R, 4, 3)

   A = M(map(R, Any[0 0 0; x^3+1 x^2 0; 0 x^2 x^5; x^4+1 x^2 x^5+x^3]))

   T = snf(A)
   @test is_snf(T)

   T, U, K = snf_with_transform(A)
   @test is_snf(T)
   @test is_unit(det(U))
   @test is_unit(det(K))
   @test U*A*K == T

   # Fake up finite field of char 7, degree 2
   R, x = polynomial_ring(GF(7), "x")
   F, = residue_field(R, x^2 + 6x + 3)
   a = F(x)

   S, y = polynomial_ring(F, "y")

   N = matrix_space(S, 3, 4)

   B = N(map(S, Any[1 0 a 0; a*y^3 0 3*a^2 0; y^4+a 0 y^2+y 5]))

   T = snf(B)
   @test is_snf(T)

   T, U, K = snf_with_transform(B)
   @test is_snf(T)
   @test is_unit(det(U))
   @test is_unit(det(K))
   @test U*B*K == T
end

@testset "Generic.Mat.weak_popov" begin
   R, x = polynomial_ring(QQ, "x")

   A = matrix(R, map(R, Any[1 2 3 x; x 2*x 3*x x^2; x x^2+1 x^3+x^2 x^4+x^2+1]))
   r = 2 # == rank(A)

   P = @inferred weak_popov(A)
   @test is_weak_popov(P, r)

   P, U = @inferred weak_popov_with_transform(A)
   @test is_weak_popov(P, r)
   @test U*A == P
   @test is_unit(det(U))

   F = GF(7)

   S, y = polynomial_ring(F, "y")

   B = matrix(S, map(S, Any[ 4*y^2+3*y+5 4*y^2+3*y+4 6*y^2+1; 3*y+6 3*y+5 y+3; 6*y^2+4*y+2 6*y^2 2*y^2+y]))
   s = 2 # == rank(B)

   P = @inferred weak_popov(B)
   @test is_weak_popov(P, s)

   P, U = @inferred weak_popov_with_transform(B)
   @test is_weak_popov(P, s)
   @test U*B == P
   @test is_unit(det(U))

   # some random tests

   for i in 1:3
      M = matrix_space(polynomial_ring(QQ, "x")[1], rand(1:5), rand(1:5))
      A = rand(M, -1:5, -5:5)
      r = rank(A)
      P = @inferred weak_popov(A)
      @test is_weak_popov(P, r)

      P, U = @inferred weak_popov_with_transform(A)
      @test is_weak_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end

   R = GF(randprime(100))

   M = matrix_space(polynomial_ring(R, "x")[1], rand(1:5), rand(1:5))

   for i in 1:2
      A = rand(M, 1:5)
      r = rank(A)
      P = @inferred weak_popov(A)
      @test is_weak_popov(P, r)

      P, U = @inferred weak_popov_with_transform(A)
      @test is_weak_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end

   R, = residue_field(ZZ, randprime(100))

   M = matrix_space(polynomial_ring(R, "x")[1], rand(1:5), rand(1:5))

   for i in 1:2
      A = rand(M, -1:5, 0:100)
      r = rank(A)
      P = @inferred weak_popov(A)
      @test is_weak_popov(P, r)

      P, U = @inferred weak_popov_with_transform(A)
      @test is_weak_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end
end

@testset "Generic.Mat.popov" begin
   R, x = polynomial_ring(QQ, "x")

   A = matrix(R, map(R, Any[1 2 3 x; x 2*x 3*x x^2; x x^2+1 x^3+x^2 x^4+x^2+1]))
   r = 2 # == rank(A)

   P = @inferred popov(A)
   @test is_popov(P, r)

   P, U = @inferred popov_with_transform(A)
   @test is_popov(P, r)
   @test U*A == P
   @test is_unit(det(U))

   A = matrix(R, 3, 3, [ x^4, 0, 0, x^3, x^4, x^3, x^3, x^5, x^5 ])
   r = 3 # == rank(A)
   P = @inferred popov(A)
   @test is_popov(P, r)

   P, U = @inferred popov_with_transform(A)
   @test is_popov(P, r)
   @test U*A == P
   @test is_unit(det(U))

   F = GF(7)

   S, y = polynomial_ring(F, "y")

   B = matrix(S, map(S, Any[ 4*y^2+3*y+5 4*y^2+3*y+4 6*y^2+1; 3*y+6 3*y+5 y+3; 6*y^2+4*y+2 6*y^2 2*y^2+y]))
   s = 2 # == rank(B)

   P = @inferred popov(B)
   @test is_popov(P, s)

   P, U = @inferred popov_with_transform(B)
   @test is_popov(P, s)
   @test U*B == P
   @test is_unit(det(U))

   # some random tests

   for i in 1:3
      M = matrix_space(polynomial_ring(QQ, "x")[1], rand(1:5), rand(1:5))
      A = rand(M, -1:5, -5:5)
      r = rank(A)
      P = @inferred popov(A)
      @test is_popov(P, r)

      P, U = @inferred popov_with_transform(A)
      @test is_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end

   R = GF(randprime(100))

   M = matrix_space(polynomial_ring(R, "x")[1], rand(1:5), rand(1:5))

   for i in 1:2
      A = rand(M, 1:5)
      r = rank(A)
      P = @inferred popov(A)
      @test is_popov(P, r)

      P, U = @inferred popov_with_transform(A)
      @test is_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end

   R, = residue_field(ZZ, randprime(100))

   M = matrix_space(polynomial_ring(R, "x")[1], rand(1:5), rand(1:5))

   for i in 1:2
      A = rand(M, -1:5, 0:100)
      r = rank(A)
      P = @inferred popov(A)
      @test is_popov(P, r)

      P, U = @inferred popov_with_transform(A)
      @test is_popov(P, r)
      @test U*A == P
      @test is_unit(det(U))
   end
end

@testset "Generic.Mat.views" begin
   M = matrix(ZZ, 3, 3, BigInt[1, 2, 3, 2, 3, 4, 3, 4, 5])
   M2 = deepcopy(M)

   N1 = @view M[:,1:2]
   N2 = @view M[1:2, :]
   N3 = @view M[:,:]

   @test isa(N1, Generic.MatSpaceView)
   @test isa(N2, Generic.MatSpaceView)
   @test isa(N3, Generic.MatSpaceView)

   @test N2*N1 == matrix(ZZ, 2, 2, BigInt[14, 20, 20, 29])
   @test N3*N3 == M*M

   @test fflu(N3) == fflu(M) # tests that deepcopy is correct
   @test M2 == M

   for i in [ 1:1, 1:2, : ], j in [ 1:1, 1:2, : ]
     v = @view M[i,j]
     @test v isa Generic.MatSpaceView
     @test M[i,j] == v
   end

   M2 = deepcopy(M)
   M3 = @view M2[2, 1:2]
   @test length(M3) == 2
   @test M3 == [2, 3]
   M3[2] = 5
   @test M2 == ZZ[1 2 3; 2 5 4; 3 4 5]

   M2 = deepcopy(M)
   M3 = @view M2[1:3, 3]
   @test length(M3) == 3
   @test M3 == [3, 4, 5]
   M3[1] = 10
   @test M2 == ZZ[1 2 10; 2 3 4; 3 4 5]

   M2 = deepcopy(M)
   M3 = @view M2[[1, 2], [1, 3]]
   @test size(M3) == (2, 2)
   @test M3 == ZZ[1 3; 2 4]
   M3[[1, 2], 1] = [8, 9]
   @test M2 == ZZ[8 2 3; 9 3 4; 3 4 5]

   M2 = deepcopy(M)
   M3 = @view M2[1, 2]
   @test size(M3) == ()
   @test length(M3) == 1
   # NOTE: The following cases are to cover all types of [gs]etindex functions.
   M3[] = ZZ(9)
   @test M3[] == 9
   M3[1] = ZZ(10)
   @test M3[1] == 10
   M3[] = 11
   @test M3[] == 11
   M3[1] = 12
   @test M3[1] == 12
   @test M2 == ZZ[1 12 3; 2 3 4; 3 4 5]

   # Test views over noncommutative ring
   R = matrix_ring(ZZ, 2)
   
   S = matrix_space(R, 4, 4)
   
   M = rand(S, -10:10)

   for i in [ 1:1, 1:2, : ], j in [ 1:1, 1:2, : ]
     v = @view M[i,j]
     @test v isa Generic.MatSpaceView
     @test M[i,j] == v
   end
end

@testset "Generic.Mat.slices" begin
  A = ZZ[1 2 3; 4 5 6]
  @test length(eachrow(A)) == nrows(A)
  @test length(eachcol(A)) == ncols(A)

  @test first(eachrow(A)) == [ZZ(1), ZZ(2), ZZ(3)]
  @test first(eachcol(A)) == [ZZ(1), ZZ(4)]

  A = zero_matrix(ZZ, 2, 0)
  @test length(eachrow(A)) == nrows(A)
  @test length(eachcol(A)) == ncols(A)
  @test first(eachrow(A)) == elem_type(ZZ)[]
end

@testset "Generic.Mat.change_base_ring" begin
   for (P, Q, T) in ((matrix_space(ZZ, 2, 3), matrix_space(ZZ, 3, 2), MatElem),
                     (matrix_ring(ZZ, 3), matrix_ring(ZZ, 3), MatRingElem))
      M = rand(P, -10:10)
      N = rand(Q, -10:10)
      for R in [QQ, ZZ, GF(2), GF(5)]
         MQ = change_base_ring(R, M)
         @test MQ isa T
         @test base_ring(MQ) == R
         NQ = change_base_ring(R, N)
         @test NQ isa T
         @test base_ring(NQ) == R
         MNQ = change_base_ring(R, M * N)
         @test MNQ isa T
         @test base_ring(MNQ) == R
         @test MQ * NQ == MNQ
      end
   end

   z = zero_matrix(F2(), 2, 3)
   @test change_base_ring(F2(), z)   isa F2Matrix
   @test change_base_ring(F2(), z.m) isa F2Matrix

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   U, x = polynomial_ring(R, "x")
   S = matrix_space(R, 2, 2)
   
   M = rand(S, -10:10)

   N = change_base_ring(U, M)

   @test isa(N, MatElem)
end

@testset "Generic.Mat.map" begin
   u, v = rand(0:9, 2)
   for (mat, algebra) = ((rand(1:9, u, v), false),
                         (rand(1:9, u, u), true))
      for R = [QQ, ZZ, GF(2), GF(7), polynomial_ring(GF(5), 'x')[1]]
         M = algebra ? matrix_ring(R, u) : matrix_space(R, u, v)
         m0 = M(mat)
         for f0 = (x -> x + 1, x -> x*2, x -> one(R), x -> zero(R))
            for f = (f0, map_from_func(f0, R, R))
               m = deepcopy(m0)
               n0 = similar(m)
               n = map_entries!(f, n0, m)
               @test n === n0 # map! must return its argument
               if !isempty(mat)
                  # when empty, it may happen that the result of map below has Any
                  # as eltype, and calling M on it fails, cf. issue #423
                  @test n == M(map(f isa Function ? f : f.image_fn, mat))
               end
            end
         end
      end
      m0 = algebra ? matrix_ring(ZZ, u)(mat) : matrix_space(ZZ, u, v)(mat)
      m = deepcopy(m0)
      for S = [QQ, ZZ, GF(2), GF(7), polynomial_ring(GF(5), 'x')[1]]
         for f0 = (x -> S(x), x -> S(x + 1))
            for f = (f0, map_from_func(f0, ZZ, S))
               n = map_entries(f, m)
               @test n !== m
               @test m == m0 # map's input must not be mutated
               M = algebra ? matrix_ring(S, u) : matrix_space(S, u, v)
               if !isempty(mat)
                  @test n == M(map(f isa Function ? f : f.image_fn, mat))
               end
               @test n isa (algebra ? MatRingElem : MatElem)
            end
         end
      end
   end

   z = zero_matrix(F2(), 2, 3)
   @test map(identity, z)   isa F2Matrix
   @test map(identity, z.m) isa F2Matrix

   # Tests over noncommutative ring
   R = matrix_ring(ZZ, 2)
   U, x = polynomial_ring(R, "x")
   S = matrix_space(R, 2, 2)
   T = matrix_space(U, 2, 2)

   M = rand(S, -10:10)
   N = rand(T, 0:5, -10:10)
   P = map(x->x^2, M)
   Q = map(x->x^2, N)

   @test isa(P, MatElem)
   @test isa(Q, MatElem)
end

@testset "Generic.Mat.similar/zero" begin
   for sim_zero in (similar, zero)
      test_zero = sim_zero === zero
      for R = (ZZ, GF(11))
         M = matrix_space(R, rand(0:9), rand(0:9))
         m = R == ZZ ? rand(M, -10:10) : rand(M)
         n = sim_zero(m)
         @test !test_zero || iszero(n)
         @test parent(n) == M
         @test size(n) == (nrows(M), ncols(M))
         r, c = rand(0:9, 2)
         n = sim_zero(m, r, c)
         @test !test_zero || iszero(n)
         @test parent(n) == matrix_space(R, r, c)
         @test size(n) == (r, c)
         for S = [QQ, ZZ, GF(2), GF(5)]
            n = sim_zero(m, S)
            @test !test_zero || iszero(n)
            @test parent(n) == matrix_space(S, size(n)...)
            @test size(n) == (nrows(M), ncols(M))
            r, c = rand(0:9, 2)
            n = sim_zero(m, S, r, c)
            @test !test_zero || iszero(n)
            @test parent(n) == matrix_space(S, r, c)
            @test size(n) == (r, c)
         end
      end
   end

   z = zero_matrix(F2(), 2, 3)
   @test z isa F2Matrix
   @test similar(z)       isa F2Matrix
   @test similar(z, 2, 3) isa F2Matrix
   @test zero(z)          isa F2Matrix
   @test zero(z, 2, 3)    isa F2Matrix

   m = z.m
   @test m                isa Generic.MatSpaceElem{F2Elem}
   @test similar(m)       isa Generic.MatSpaceElem{F2Elem}
   @test similar(m, 2, 3) isa Generic.MatSpaceElem{F2Elem}
   @test zero(m)          isa Generic.MatSpaceElem{F2Elem}
   @test zero(m, 2, 3)    isa Generic.MatSpaceElem{F2Elem}
end

@testset "Generic.Mat.printing" begin
   # this is the REPL printing
   @test sprint(show, "text/plain", matrix(ZZ, [3 1 2; 2 0 1])) == "[3   1   2]\n[2   0   1]"
   @test sprint(show, "text/plain", matrix(ZZ, [3 1 2; 2 0 1])) == "[3   1   2]\n[2   0   1]"
   @test sprint(show, "text/plain", matrix(ZZ, 2, 0, [])) == "2 by 0 empty matrix"
   @test sprint(show, "text/plain", matrix(ZZ, 0, 3, [])) == "0 by 3 empty matrix"
   S = matrix_ring(QQ, 3)
   @test sprint(show, "text/plain", S([1 2 3; 4 5 6; 7 8 9])) ==
      "[1//1   2//1   3//1]\n[4//1   5//1   6//1]\n[7//1   8//1   9//1]"
   @test sprint(show, "text/plain", matrix_ring(QQ, 0)()) == "0 by 0 empty matrix"
   @test sprint(show, "text/plain", similar(matrix(ZZ, [3 1 2; 2 0 1]))) ==
      "[#undef   #undef   #undef]\n[#undef   #undef   #undef]"

   @test sprint(show, matrix(ZZ, [3 1 2; 2 0 1])) == "[3 1 2; 2 0 1]"

   R, x = polynomial_ring(ZZ, "x")

   @test sprint(show, matrix(R, [-x-1 -x; 2*x+1 -1])) == "[-x-1 -x; 2*x+1 -1]"

   @test sprint(show, "text/plain", matrix(R, [-x-1 -x; x+1 -1])) ==
                                                       "[-x - 1   -x]\n[ x + 1   -1]"

   @test !occursin("\n", sprint(show, matrix_space(R, 3, 4)))
end

@testset "Generic.Mat.array_conversion" begin
   M = ZZ[1 2; 3 4]
   A = Array(M)
   @test A  == M.entries
   @test A !== M.entries
   @test Matrix(M) == A
   @test eltype(A) == eltype(M)

   F = matrix(F2(), F2Elem[1 1 1; 0 0 0])
   B = Array(F)
   @test B ==  F.m.entries
   @test B !== F.m.entries
   @test Matrix(F) == B
   @test eltype(B) == F2Elem
end

@testset "Generic.Mat.rand" begin
   M = matrix_space(ZZ, 2, 3)
   test_rand(M, 1:9)

   M = matrix_space(GF(7), 3, 2)
   test_rand(M)

   sp = Random.Sampler(MersenneTwister, M)
   @test parent(rand(sp)) == M
   v = rand(sp, 3)
   @test v isa Vector{elem_type(M)}
   @test all(x -> parent(x) == M, v)

   M = matrix_space(F2(), 2, 3)
   test_rand(M)
end

@testset "Generic.Mat.MatSpace_iteration" begin
   F = GF(2)
   M = matrix_space(F, 2, 2)
   xs = collect(M)
   ys = [ [0 0; 0 0], [1 0; 0 0], [0 1; 0 0], [1 1; 0 0],
          [0 0; 1 0], [1 0; 1 0], [0 1; 1 0], [1 1; 1 0],
          [0 0; 0 1], [1 0; 0 1], [0 1; 0 1], [1 1; 0 1],
          [0 0; 1 1], [1 0; 1 1], [0 1; 1 1], [1 1; 1 1] ]
   @test xs == M.(ys)

   M = matrix_space(F, 0, 2)
   @test collect(M) == [ M() ]

   F = GF(5)
   M = matrix_space(F, 3, 4)
   xs = collect(Iterators.take(M, 10))
   ys = [ [0 0 0 0; 0 0 0 0; 0 0 0 0], [1 0 0 0; 0 0 0 0; 0 0 0 0],
          [2 0 0 0; 0 0 0 0; 0 0 0 0], [3 0 0 0; 0 0 0 0; 0 0 0 0],
          [4 0 0 0; 0 0 0 0; 0 0 0 0], [0 1 0 0; 0 0 0 0; 0 0 0 0],
          [1 1 0 0; 0 0 0 0; 0 0 0 0], [2 1 0 0; 0 0 0 0; 0 0 0 0],
          [3 1 0 0; 0 0 0 0; 0 0 0 0], [4 1 0 0; 0 0 0 0; 0 0 0 0] ]
   @test xs == M.(ys)
   @test M([3 2 0 0; 0 0 0 0; 0 0 0 0]) in M

   M = matrix_space(F, 1, 0)
   @test collect(M) == [ M() ]
end

@testset "Generic.Mat.InjProjMat" begin
   # Construction
   @test matrix(Generic.inj_proj_mat(QQ, 3, 2, 1)) == QQ[1 0; 0 1; 0 0]
   @test matrix(Generic.inj_proj_mat(QQ, 2, 3, 1)) == QQ[1 0 0; 0 1 0]
   @test matrix(Generic.inj_proj_mat(QQ, 3, 2, 2)) == QQ[0 0; 1 0; 0 1]
   @test matrix(Generic.inj_proj_mat(QQ, 2, 3, 2)) == QQ[0 1 0; 0 0 1]

   @test_throws AssertionError Generic.inj_proj_mat(QQ, 3, 2, 0)
   @test_throws AssertionError Generic.inj_proj_mat(QQ, 3, 2, 3)
   @test_throws AssertionError Generic.inj_proj_mat(QQ, 2, 3, 3)

   # Getters
   M = Generic.inj_proj_mat(QQ, 4, 2, 2)
   Mt = Generic.inj_proj_mat(QQ, 2, 4, 2)
   @test nrows(M) == 4
   @test ncols(M) == 2
   R = @inferred base_ring(M)
   @test R === QQ

   # getindex
   N = QQ[0 0; 1 0; 0 1; 0 0]
   Nt = transpose(N)
   @test matrix(Mt) == Nt
   for i in 1:4
      for j in 1:2
         x = @inferred M[i, j]
         @test x == N[i, j]
      end
   end

   # Multiplication
   @test_throws AssertionError M*identity_matrix(QQ, 1)
   @test_throws AssertionError identity_matrix(QQ, 1)*M
   for iter in 1:10
      d = rand(1:10)
      X = matrix(QQ, 2, d, [ rand(QQ, -10:10) for _ in 1:2*d ])
      @test M*X == N*X
      @test transpose(X)*Mt == transpose(X)*Nt

      X = matrix(QQ, d, 4, [ rand(QQ, -10:10) for _ in 1:4*d ])
      @test X*M == X*N
      @test Mt*transpose(X) == Nt*transpose(X)

      d = rand(2:10)
      s = rand(1:d - 1)
      X = Generic.inj_proj_mat(QQ, 2, d, s)
      @test M*X == N*matrix(X)
   end

   # Catch all cases
   for iter in 1:10
      M1 = Generic.inj_proj_mat(QQ, 5, 3, rand(1:3))
      M2 = Generic.inj_proj_mat(QQ, 3, 2, rand(1:2))
      @test M1*M2 == matrix(M1)*matrix(M2)

      M1 = Generic.inj_proj_mat(QQ, 5, 3, rand(1:3))
      M2 = Generic.inj_proj_mat(QQ, 3, 4, rand(1:2))
      @test M1*M2 == matrix(M1)*matrix(M2)

      M1 = Generic.inj_proj_mat(QQ, 3, 5, rand(1:3))
      M2 = Generic.inj_proj_mat(QQ, 5, 2, rand(1:4))
      @test M1*M2 == matrix(M1)*matrix(M2)

      M1 = Generic.inj_proj_mat(QQ, 3, 5, rand(1:3))
      M2 = Generic.inj_proj_mat(QQ, 5, 7, rand(1:3))
      @test M1*M2 == matrix(M1)*matrix(M2)
   end

   # Addition
   @test_throws AssertionError M + zero_matrix(QQ, 4, 1)
   @test_throws AssertionError zero_matrix(QQ, 4, 1) + M
   for iter in 1:10
      X = matrix(QQ, 4, 2, [ rand(QQ, -10:10) for _ in 1:4*2 ])
      @test M + X == N + X
      @test Mt + transpose(X) == Nt + transpose(X)
      @test X + M == X + N

      s = rand(1:3)
      X = Generic.inj_proj_mat(QQ, 4, 2, s)
      @test M + X == N + matrix(X)
   end
end

@testset "Generic.Mat.unsafe" begin
  a = QQ[1 2 3; 4 5 6]
  b = QQ[1 1 1; 1 1 1]
  c = zero_matrix(QQ, 2, 3)
  c = add!(c, a, b)
  @test c == a + b
  c = sub!(c, a, b)
  @test c == a - b

  b = transpose(b)
  c = zero_matrix(QQ, 2, 2)
  c = mul!(c, a, b)
  @test c == a * b

  c = zero_matrix(QQ, 2, 3)
  c = mul!(c, a, QQ(2))
  @test c == a * QQ(2)

  b = transpose(a)
  @test AbstractAlgebra.transpose!(a) == b
end
