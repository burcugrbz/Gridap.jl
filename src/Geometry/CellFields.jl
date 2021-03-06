
"""
    abstract type CellFieldLike <: GridapType end
"""
abstract type CellFieldLike <: GridapType end

"""
    get_array(cf::CellFieldLike)
"""
function get_array(cf::CellFieldLike)
  @abstractmethod
end

"""
    get_cell_map(cf::CellFieldLike)
"""
function get_cell_map(cf::CellFieldLike)
  @abstractmethod
end

"""
This trait returns `Val{true}()` when the `CellFieldLike` is defined in a
reference finite element space, and `Val{false}()` when it is defined in the
physical space
"""
RefStyle(::Type{<:CellFieldLike}) = @notimplemented

# We use duck typing here for all types marked with the RefStyle
RefStyle(::Type) = @notimplemented
RefStyle(a) = RefStyle(typeof(a))
is_in_ref_space(::Type{T}) where T = get_val_parameter(RefStyle(T))
is_in_ref_space(::T) where T = is_in_ref_space(T)
is_in_physical_space(::Type{T}) where T = !is_in_ref_space(T)
is_in_physical_space(a::T) where T = !is_in_ref_space(T)

to_ref_space(a::CellFieldLike) = _to_ref_space(a,RefStyle(a))
_to_ref_space(a,::Val{true}) = a
function _to_ref_space(a,::Val{false})
  cell_map = get_cell_map(a)
  array = compose(  get_array(a), cell_map  )
  no = similar_object(a,array)
  change_ref_style(no)
end

to_physical_space(a::CellFieldLike) = _to_physical_space(a,RefStyle(a))
_to_physical_space(a,::Val{true}) = @notimplemented # and probably not doable in some cases
_to_physical_space(a,::Val{false}) = a

# Assumption : x ALWAIS defined in the reference space
# In the future we can also add the RefStyle to x
"""
    evaluate(cf::CellFieldLike,x)
"""
function evaluate(cf::CellFieldLike,x::AbstractArray)
  _evaluate(cf,x,RefStyle(cf))
end

function _evaluate(cf::CellFieldLike,x::AbstractArray,::Val{true})
  evaluate_field_array(get_array(cf),x)
end

function _evaluate(cf::CellFieldLike,x::AbstractArray,::Val{false})
  cm = get_cell_map(cf)
  _x = evaluate(cm,x)
  evaluate_field_array(get_array(cf),_x)
end

"""
    similar_object(cf::CellFieldLike,array::AbstractArray)
"""
function similar_object(cf::CellFieldLike,array::AbstractArray)
  @abstractmethod
end

"""
    similar_object(cf1::CellFieldLike,cf2::CellFieldLike,array::AbstractArray)
"""
function similar_object(cf1::CellFieldLike,cf2::CellFieldLike,array::AbstractArray)
  @abstractmethod
end

"""
   change_ref_style(cf::CellFieldLike)

Return an object with the same array and metadata as in `cf`, except for `RefStyle` which is changed.
"""
function change_ref_style(cf::CellFieldLike)
  @abstractmethod
end

"""
    gradient(cf::CellFieldLike)
"""
function gradient(cf::CellFieldLike)
  @abstractmethod
end

"""
    grad2curl(cf::CellFieldLike)
"""
function grad2curl(cf::CellFieldLike)
  @abstractmethod
end

"""
    test_cell_field_like(
      cf::CellFieldLike,
      x::AbstractArray,
      b::AbstractArray,
      pred=(==);
      grad=nothing)
"""
function test_cell_field_like(cf::CellFieldLike,x::AbstractArray,b::AbstractArray,pred=(==);grad=nothing)
  cell_map = get_cell_map(cf)
  @test isa(cell_map,AbstractArray)
  a = evaluate(cf,x)
  test_array(a,b,pred)
  if grad != nothing
    g = evaluate(gradient(cf),x)
    test_array(g,grad,pred)
  end
  rs = RefStyle(cf)
  @test isa(get_val_parameter(rs),Bool)
  _cf = change_ref_style(cf)
  @test get_array(_cf) === get_array(cf)
  @test is_in_ref_space(cf) == !is_in_ref_space(_cf)
  @test is_in_physical_space(cf) == !is_in_physical_space(_cf)
end

"""
    length(cf::CellFieldLike)
"""
function Base.length(cf::CellFieldLike)
  a = get_array(cf)
  length(a)
end

function reindex(cf::CellFieldLike,a::AbstractVector)
  similar_object(cf,reindex(get_array(cf),a))
end

"""
    abstract type CellField <: CellFieldLike end
"""
abstract type CellField <: CellFieldLike end

"""
    test_cell_field(cf::CellField,args...;kwargs...)

Same arguments as [`test_cell_field_like`](@ref)
"""
function test_cell_field(cf::CellField,args...;kwargs...)
  test_cell_field_like(cf,args...;kwargs...)
end

function similar_object(cf::CellField,array::AbstractArray)
  cm = get_cell_map(cf)
  GenericCellField(array,cm,RefStyle(cf))
end

function similar_object(cf1::CellField,cf2::CellField,array::AbstractArray)
  cm = get_cell_map(cf1)
  @assert is_in_ref_space(cf1) == is_in_ref_space(cf2)
  GenericCellField(array,cm,RefStyle(cf1))
end

function change_ref_style(cf::CellField)
  ref_sty = RefStyle(cf)
  bool = !get_val_parameter(ref_sty)
  new_sty = Val{bool}()
  ar = get_array(cf)
  cm = get_cell_map(cf)
  GenericCellField(ar,cm,new_sty)
end

# Diff operations

struct UnimplementedField <: Field end

function gradient(cf::CellField)
  a = get_array(cf)
  g = field_array_gradient(a)
  similar_object(cf,g)
end

function grad2curl(cf::CellField)
  a = get_array(cf)
  g = grad2curl(UnimplementedField,a)
  similar_object(cf,g)
end

# Operations

function operate(op,cf::CellField)
  a = get_array(cf)
  b = field_array_operation(UnimplementedField,op,a)
  similar_object(cf,b)
end

function operate(op,cf1::CellField,cf2::CellField)
  @assert length(cf1) == length(cf2)
  a1 = get_array(cf1)
  a2 = get_array(cf2)
  b = field_array_operation(UnimplementedField,op,a1,a2)
  similar_object(cf1,cf2,b)
end

function operate(op,cf1::CellField,object)
  cm = get_cell_map(cf1)
  cf2 = convert_to_cell_field(object,cm,RefStyle(cf1))
  operate(op,cf1,cf2)
end

function operate(op,object,cf2::CellField)
  cm = get_cell_map(cf2)
  cf1 = convert_to_cell_field(object,cm,RefStyle(cf2))
  operate(op,cf1,cf2)
end

# Conversions

function convert_to_cell_field(object,cell_map)
  ref_style = Val{true}()
  convert_to_cell_field(object,cell_map,ref_style)
end

"""
    convert_to_cell_field(object,cell_map,ref_style)
"""
function convert_to_cell_field(object::CellField,cell_map,ref_style::Val)
  @assert RefStyle(object) == ref_style
  object
end

function convert_to_cell_field(object::CellField,cell_map)
  ref_style = RefStyle(object)
  convert_to_cell_field(object,cell_map,ref_style)
end

function convert_to_cell_field(object::AbstractArray,cell_map,ref_style::Val)
  @assert length(object) == length(cell_map)
  GenericCellField(object,cell_map,ref_style)
end

function convert_to_cell_field(object::Function,cell_map,ref_style::Val{true})
  b = compose(object,cell_map)
  GenericCellField(b,cell_map,Val{true}())
end

function convert_to_cell_field(fun::Function,cell_map,ref_style::Val{false})
  field = function_field(fun)
  cell_field = Fill(field,length(cell_map))
  GenericCellField(cell_field,cell_map,Val{false}())
end

function convert_to_cell_field(object::Number,cell_map,ref_style::Val)
  a = Fill(object,length(cell_map))
  GenericCellField(a,cell_map,ref_style)
end

# Concrete implementation

"""
struct GenericCellField{R} <: CellField
      array::AbstractArray
      cell_map::AbstractArray
      ref_trait::Val{R}
    end
"""
struct GenericCellField{R} <: CellField
  array::AbstractArray
  cell_map::AbstractArray
  ref_trait::Val{R}
end

function GenericCellField(array::AbstractArray,cell_map::AbstractArray)
  GenericCellField(array,cell_map,Val{true}())
end

function get_array(cf::GenericCellField)
  cf.array
end

function get_cell_map(cf::GenericCellField)
  cf.cell_map
end

function RefStyle(::Type{<:GenericCellField{R}}) where {R}
  Val{R}()
end

# Skeleton related

"""
    struct SkeletonCellField <: GridapType
      left::CellField
      right::CellField
    end

Supports the same differential and algebraic operations than [`CellField`](@ref)
"""
struct SkeletonCellField <: GridapType
  left::CellField
  right::CellField
end

function Base.getproperty(x::SkeletonCellField, sym::Symbol)
  if sym == :inward
    x.left
  elseif sym == :outward
    x.right
  else
    getfield(x, sym)
  end
end

"""
    get_cell_map(a::SkeletonCellField)
"""
function get_cell_map(a::SkeletonCellField)
  get_cell_map(a.left)
end

"""
    jump(sf::SkeletonCellField)
"""
function jump(sf::SkeletonCellField)
  sf.left - sf.right
end

"""
    mean(sf::SkeletonCellField)
"""
function mean(sf::SkeletonCellField)
  operate(_mean,sf.left,sf.right)
end

_mean(x,y) = 0.5*x + 0.5*y

function gradient(cf::SkeletonCellField)
  left = gradient(cf.left)
  right = gradient(cf.right)
  SkeletonCellField(left,right)
end

function grad2curl(cf::SkeletonCellField)
  left = grad2curl(cf.left)
  right = grad2curl(cf.right)
  SkeletonCellField(left,right)
end

function operate(op,cf::SkeletonCellField)
  left = operate(op,cf.left)
  right = operate(op,cf.right)
  SkeletonCellField(left,right)
end

function operate(op,cf1::SkeletonCellField,cf2::SkeletonCellField)
  left = operate(op,cf1.left,cf2.left)
  right = operate(op,cf1.right,cf2.right)
  SkeletonCellField(left,right)
end

function operate(op,cf1::SkeletonCellField,cf2::CellField)
  left = operate(op,cf1.left,cf2)
  right = operate(op,cf1.right,cf2)
  SkeletonCellField(left,right)
end

function operate(op,cf1::CellField,cf2::SkeletonCellField)
  left = operate(op,cf1,cf2.left)
  right = operate(op,cf1,cf2.right)
  SkeletonCellField(left,right)
end

function operate(op,cf1::SkeletonCellField,object)
  cm = get_cell_map(cf1)
  cf2 = convert_to_cell_field(object,cm,RefStyle(cf1.left))
  operate(op,cf1,cf2)
end

function operate(op,object,cf2::SkeletonCellField)
  cm = get_cell_map(cf2)
  cf1 = convert_to_cell_field(object,cm,RefStyle(cf2.left))
  operate(op,cf1,cf2)
end
