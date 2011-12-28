module Language.StreamIt.Filter
  ( Statement (..)
  , evalStmt
  , Filter (..)
  , FilterInfo
  , push
  , peek
  , pop
  , incr
  , decr
  , println
  , work
  , init'
  , ifelse
  , if_
  , case_
  , (==>)
  , for_
  ) where

import Control.Monad

import Language.StreamIt.Core

infixr 0 ==>

data Statement where
  Decl     :: AllE a => V a -> Statement
  Assign   :: AllE a => V a -> E a -> Statement
  Branch   :: E Bool -> Statement -> Statement -> Statement
  Loop     :: Statement -> E Bool -> Statement -> Statement -> Statement
  Sequence :: Statement -> Statement -> Statement
  Work     :: (E Int, E Int, E Int) -> Statement -> Statement
  Init     :: Statement -> Statement
  Push     :: AllE a => E a -> Statement
  Pop      :: Statement
  Peek     :: V Int -> Statement
  Println  :: Statement -> Statement
  Null     :: Statement

instance Eq Statement where (==) _ _ = True

-- | The Filter monad holds StreamIt filter statements.
data Filter a = Filter ((Int, Statement) -> (a, (Int, Statement)))

instance Monad Filter where
  return a = Filter $ \ s -> (a, s)
  (Filter f1) >>= f2 = Filter f3
    where
    f3 s1 = f4 s2
      where
      (a, s2) = f1 s1
      Filter f4 = f2 a

statement :: Statement -> Filter ()
statement a = Filter $ \ (id, statement) -> ((), (id, Sequence statement a))

evalStmt :: Int -> Filter () -> (Int, Statement)
evalStmt id (Filter f) = snd $ f (id, Null)

evalStmt':: Filter () -> Statement 
evalStmt' f = snd (evalStmt 0 f)

get :: Filter (Int, Statement)
get = Filter $ \ a -> (a, a)

put :: (Int, Statement) -> Filter ()
put s = Filter $ \ _ -> ((), s)

type FilterInfo = (TypeSig, Name, Statement)

instance DeclE (Filter) where
  var input name init = do
    (id, stmt) <- get
    put (id, Sequence stmt $ Decl (V input name init))
    return $ V input name init
  input _ name = var True name zero
  float name = var False name zero
  float' = var False
  int name = var False name zero
  int' = var False
  bool name = var False name zero
  bool' = var False
  a <== b = statement $ Assign a b

-- | Increments an E Int.
incr :: V Int -> Filter ()
incr a = a <== ref a + 1

-- | Decrements an E Int.
decr :: V Int -> Filter ()
decr a = a <== ref a - 1

-- | Push
push :: AllE a => E a -> Filter ()
push a = statement $ Push a

-- | Peek
peek :: V Int -> Filter ()
peek a = statement $ Peek a

-- | Pop
pop :: Filter ()
pop = statement $ Pop

-- | Println
println :: Filter () -> Filter ()
println f = statement $ Println (evalStmt' f)

-- | Init
init' :: Filter () -> Filter ()
init' s = do
  (id0, stmt) <- get
  let (id1, stmt1) = evalStmt id0 s
  put (id1, stmt)
  statement $ Init stmt1

-- | Work
work :: (E Int, E Int, E Int) -> Filter () -> Filter ()
work (push, pop, peek) s = do
  (id0, stmt) <- get
  let (id1, stmt1) = evalStmt id0 s
  put (id1, stmt)
  statement $ Work (push, pop, peek) stmt1

-- | Conditional if-else.
ifelse :: E Bool -> Filter () -> Filter () -> Filter ()
ifelse cond onTrue onFalse = do
  (id0, stmt) <- get
  let (id1, stmt1) = evalStmt id0 onTrue
      (id2, stmt2) = evalStmt id1 onFalse
  put (id2, stmt)
  statement $ Branch cond stmt1 stmt2

-- | Conditional if without the else.
if_ :: E Bool -> Filter () -> Filter ()
if_ cond stmt = ifelse cond stmt $ return ()

-- | Condition case statement.
case_ :: Case () -> Filter ()
case_ (Case f) = f $ return ()

data Case a = Case (Filter () -> Filter ())
instance Monad Case where
  return _ = Case id
  (>>=) = undefined
  (Case f1) >> (Case f2) = Case $ f1 . f2

(==>) :: E Bool -> Filter () -> Case ()
a ==> s = Case $ ifelse a s

-- | For loop.
for_ :: (Filter (), E Bool, Filter ()) -> Filter () -> Filter ()
for_ (init, cond, inc) body = do
  (id0, stmt) <- get
  let (id1, stmt1) = evalStmt id0 body
  put (id1, stmt)
  statement $ Loop (evalStmt' init) cond (evalStmt' inc) stmt1