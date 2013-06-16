module Language.StreamIt.Core
  ( Exp (..)
  , Var (..)
  , CoreE (..)
  , TypeSig
  , Name
  , Elt (..)
  , NumE
  , Const (..)
  , Void
  , Array (..)
  , true
  , false
  , constant
  , ref
  , not_
  , (&&.)
  , (||.)
  , and_
  , or_
  , (==.)
  , (/==.)
  , (<.)
  , (<=.)
  , (>.)
  , (>=.)
  , (.++)
  , (.--)
  , (+=.)
  , (-=.)
  , (*=.)
  , (/=.)
  , mod_
  , showTypeSig
  , showConstType
  , isScalar
  , (!)
  ) where

import Data.List
import Data.Ratio
import Data.Typeable

infixl 9 !
infixl 7 `mod_`
infix  4 ==., /==., <., <=., >., >=.
infix  4 .++, .--, +=., -=., *=., /=.
infixl 3 &&.
infixl 2 ||.
infixr 0 <==

type TypeSig = String
type Name = String

-- | A mutable variable.
data Var a = Var {
  inp   :: Bool,      -- if the variable is a filter input or not
  vname :: Name,      -- name of the variable
  val   :: Elt a => a -- initial value
  }

instance Show (Var a) where
  show (Var _ n _) = n

class Eq a => Elt a where
  zero   :: a
  const' :: a -> Const

instance Elt Bool where
  zero = False
  const' = Bool

instance Elt Int where
  zero = 0
  const' = Int

instance Elt Float where
  zero = 0
  const' = Float

class    (Elt a, Num a, Ord a) => NumE a
instance NumE Int
instance NumE Float

data Void
instance Show Void where show _ = "Void"
instance Eq Void where _ == _ = True
instance Ord Void where _ <= _ = True
instance Typeable Void where typeOf _ = mkTyConApp (mkTyCon3 "" "" "Void") []

instance Elt Void where
  zero = undefined
  const' = Void

-- | A phantom type for describing StreamIt array types.
data Array a = Array {
  bound :: Exp Int, -- array upper bound
  ele   :: a        -- array element type
  } deriving (Show, Eq)

instance (Elt a) => Elt (Array a) where
  zero = Array (constant 0) zero
  const' (Array b e) = ArrayT b (const' e)

-- | Generic variable declarations.
class Monad a => CoreE a where
  var    :: Elt b  => Bool -> b -> a (Var b)
  input  :: Elt b => a (Var b) -> a (Var b)

  -- Float variable declarations.
  float  :: a (Var Float)
  float' :: Float -> a (Var Float)
  -- Int variable declarations.
  int    :: a (Var Int)
  int'   :: Int -> a (Var Int)
  -- Bool variable declarations.
  bool   :: a (Var Bool)
  bool'  :: Bool -> a (Var Bool)
  -- Array declarations.
  array  :: Elt b => a (Var b) -> Exp Int -> a (Var (Array b))
  -- Assignments.
  (<==)  :: Elt b => Var b -> Exp b -> a ()
  -- Conditional statements.
  ifelse :: Exp Bool -> a () -> a () -> a ()
  if_    :: Exp Bool -> a () -> a ()
  -- Loops
  for_   :: (a (), Exp Bool, a ()) -> a () -> a ()
  while_ :: Exp Bool -> a () -> a ()

-- | A logical, arithmetic, comparative, or conditional expression.
data Exp a where
  Ref   :: Elt a => Var a -> Exp a
  Peek  :: Elt a => Exp Int -> Exp a -- RRN: this has an effect so it should be in the
                                     -- Filter monad.
  Const :: Elt a => a -> Exp a
  Add   :: NumE a => Exp a -> Exp a -> Exp a
  Sub   :: NumE a => Exp a -> Exp a -> Exp a
  Mul   :: NumE a => Exp a -> Exp a -> Exp a
  Div   :: NumE a => Exp a -> Exp a -> Exp a
  Mod   :: Exp Int -> Int -> Exp Int
  Not   :: Exp Bool -> Exp Bool
  And   :: Exp Bool -> Exp Bool -> Exp Bool
  Or    :: Exp Bool -> Exp Bool -> Exp Bool
  Eq    :: Elt a => Exp a -> Exp a -> Exp Bool
  Lt    :: NumE a => Exp a -> Exp a -> Exp Bool
  Gt    :: NumE a => Exp a -> Exp a -> Exp Bool
  Le    :: NumE a => Exp a -> Exp a -> Exp Bool
  Ge    :: NumE a => Exp a -> Exp a -> Exp Bool
  Mux   :: Elt a => Exp Bool -> Exp a -> Exp a -> Exp a

instance Show (Exp a) where
  show a = case a of
    Ref a     -> show a
    Peek a    -> "peek(" ++ show a ++ ")"
    Const a   -> show $ const' a
    Add a b   -> group [show a, "+", show b]
    Sub a b   -> group [show a, "-", show b]
    Mul a b   -> group [show a, "*", show b]
    Div a b   -> group [show a, "/", show b]
    Mod a b   -> group [show a, "%", show (const' b)]
    Not a     -> group ["!", show a]
    And a b   -> group [show a, "&&",  show b]
    Or  a b   -> group [show a, "||",  show b]
    Eq  a b   -> group [show a, "==",  show b]
    Lt  a b   -> group [show a, "<",   show b]
    Gt  a b   -> group [show a, ">",   show b]
    Le  a b   -> group [show a, "<=",  show b]
    Ge  a b   -> group [show a, ">=",  show b]
    Mux a b c -> group [show a, "?", show b, ":", show c] 
    where
      group :: [String] -> String
      group a = "(" ++ intercalate " " a ++ ")"

instance Eq a => Eq (Exp a) where
  a == b = evalExp a == evalExp b

instance NumE a => Num (Exp a) where
  (+) = Add
  (-) = Sub
  (*) = Mul
  negate a = 0 - a
  abs a = Mux (Lt a 0) (negate a) a
  signum a = Mux (Eq a 0) 0 $ Mux (Lt a 0) (-1) 1
  fromInteger = Const . fromInteger

instance Fractional (Exp Int) where
  (/) = Div
  fromRational = undefined

instance Fractional (Exp Float) where
  (/) = Div
  recip a = 1 / a
  fromRational r = Const $ fromInteger (numerator r) / fromInteger (denominator r)

evalExp :: Exp a -> a
evalExp e = case e of
  Ref a     -> val a
  Peek _    -> error "peek" -- ADK: Peek should not be here.
  Const a   -> a
  Add a b   -> evalExp a + evalExp b
  Sub a b   -> evalExp a - evalExp b
  Mul a b   -> evalExp a * evalExp b
  Div _ _   -> undefined
  Mod a b   -> evalExp a `mod` b
  Not a     -> not $ evalExp a
  And a b   -> evalExp a &&  evalExp b
  Or  a b   -> evalExp a ||  evalExp b
  Eq  a b   -> evalExp a ==  evalExp b
  Lt  a b   -> evalExp a < evalExp b
  Gt  a b   -> evalExp a > evalExp b
  Le  a b   -> evalExp a <= evalExp b
  Ge  a b   -> evalExp a >= evalExp b
  Mux a b c -> if (evalExp a) then evalExp b else evalExp c

data Const
  = Bool   Bool
  | Int    Int
  | Float  Float
  | Void   Void
  | ArrayT (Exp Int) Const
  deriving (Eq)

isScalar :: Const -> Bool
isScalar c = case c of
  ArrayT _ _ -> False
  _        -> True

instance Show (Const) where
  show a = case a of
    Bool  True  -> "true"
    Bool  False -> "false"
    Int   a     -> show a
    Float a     -> show a
    Void _      -> ""
    ArrayT b e  -> "{" ++ (intercalate "," $ replicate (evalExp b) (show e)) ++ "}"

showConstType :: Const -> String
showConstType a = case a of
  Bool  _     -> "boolean"
  Int   _     -> "int"
  Float _     -> "float"
  Void _      -> "void"
  ArrayT b e  -> (showConstType e) ++ "[" ++ show b ++ "]"

-- | True term.
true :: Exp Bool
true = Const True

-- | False term.
false :: Exp Bool
false = Const False

-- | Arbitrary constants.
constant :: Elt a => a -> Exp a
constant = Const

-- | Logical negation.
not_ :: Exp Bool -> Exp Bool
not_ = Not

-- | Logical AND.
(&&.) :: Exp Bool -> Exp Bool -> Exp Bool
(&&.) = And

-- | Logical OR.
(||.) :: Exp Bool -> Exp Bool -> Exp Bool
(||.) = Or

-- | Array Dereference:
(!) :: Elt a => Var (Array a) -> Exp Int -> Var a 
(Var inp name arr) ! idx = -- ADK: NOTE: We might not be able to statically evaluate the
                           --      index every time. This is just an optimistic check.
  let i = evalExp idx in
  let b = evalExp $ (bound arr) in
  if (i <= b) then Var inp (name ++ "[" ++ show idx ++ "]") $ ele arr
  else error $ "invalid array index: " ++ show i ++ " in " ++ name ++ "[" ++ show b ++ "]"

-- | The conjunction of a Exp Bool list.
and_ :: [Exp Bool] -> Exp Bool
and_ = foldl (&&.) true

-- | The disjunction of a Exp Bool list.
or_ :: [Exp Bool] -> Exp Bool
or_ = foldl (||.) false

-- | Equal.
(==.) :: Elt a => Exp a -> Exp a -> Exp Bool
(==.) = Eq

-- | Not equal.
(/==.) :: Elt a => Exp a -> Exp a -> Exp Bool
a /==. b = not_ (a ==. b)

-- | Less than.
(<.) :: NumE a => Exp a -> Exp a -> Exp Bool
(<.) = Lt

-- | Greater than.
(>.) :: NumE a => Exp a -> Exp a -> Exp Bool
(>.) = Gt

-- | Less than or equal.
(<=.) :: NumE a => Exp a -> Exp a -> Exp Bool
(<=.) = Le

-- | Greater than or equal.
(>=.) :: NumE a => Exp a -> Exp a -> Exp Bool
(>=.) = Ge

-- | Modulo.
mod_ :: Exp Int -> Int -> Exp Int
mod_ _ 0 = error "divide by zero (mod_)"
mod_ a b = Mod a b

-- | References a variable to be used in an expression.
ref :: Elt a => Var a -> Exp a
ref = Ref

-- | Increments a Var Int.
(.++) :: CoreE a => Var Int -> a ()
(.++) a = a <== ref a + 1

-- | Decrements a Var Int.
(.--) :: CoreE a => Var Int -> a ()
(.--) a = a <== ref a - 1

-- | Sum assign a Var Int.
(+=.) :: CoreE a => Var Int -> Var Int -> a ()
a +=. b = a <== ref a + ref b

-- | Subtract and assign a Var Int.
(-=.) :: CoreE a => Var Int -> Var Int -> a ()
a -=. b = a <== ref a - ref b

-- | Product assign a Var Int.
(*=.) :: CoreE a => Var Int -> Var Int -> a ()
a *=. b = a <== ref a * ref b

-- | Divide and assign a Var Int.
(/=.) :: CoreE a => Var Int -> Var Int -> a ()
a /=. b = a <== ref a / ref b

-- | Return the type signature of a Filter or StreamIt monad
showTypeSig :: Typeable a => a -> String
showTypeSig = show . typeOf
