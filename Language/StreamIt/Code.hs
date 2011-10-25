module Language.StreamIt.Code (code) where

import Data.List

import Language.StreamIt.Core

indent :: String -> String
indent = unlines . map ("\t" ++) . lines

indent' :: String -> String
indent' a = case lines a of
  [] -> []
  (a:b) -> a ++ "\n" ++ indent (unlines b)

-- | Generate StreamIt.
code :: Name -> Statement -> IO ()
code name stmt = do
  writeFile (name ++ ".c") $
    "void " ++ name ++ "()\n{\n"
    ++ indent (codeStmt name [] stmt)
    ++ "}\n\n"

instance Show Statement where show = codeStmt "none" []

codeStmt :: Name -> [Name] -> Statement -> String
codeStmt name path a = case a of
  Assign a b -> pathName a ++ " = " ++ codeExpr b ++ ";\n"
  Branch a b Null -> "if (" ++ codeExpr a ++ ") {\n" ++ indent (codeStmt name path b) ++ "}\n"
  Branch a b c    -> "if (" ++ codeExpr a ++ ") {\n" ++ indent (codeStmt name path b) ++ "}\nelse {\n" ++ indent (codeStmt name path c) ++ "}\n"
  Sequence a b -> codeStmt name path a ++ codeStmt name path b
  Push a -> "push(" ++ codeExpr a ++ ");\n"
  Pop -> "pop();\n"
  Peek a -> "peek(" ++ pathName a ++ ");\n"
  Null -> ""
  where

  codeExpr :: E a -> String
  codeExpr a = case a of
    Ref a     -> pathName a
    Const a   -> showConst $ const' a
    Add a b   -> group [codeExpr a, "+", codeExpr b]
    Sub a b   -> group [codeExpr a, "-", codeExpr b]
    Mul a b   -> group [codeExpr a, "*", showConst (const' b)]
    Div a b   -> group [codeExpr a, "/", showConst (const' b)]
    Mod a b   -> group [codeExpr a, "%", showConst (const' b)]
    Not a     -> group ["!", codeExpr a]
    And a b   -> group [codeExpr a, "&&",  codeExpr b]
    Or  a b   -> group [codeExpr a, "||",  codeExpr b]
    Eq  a b   -> group [codeExpr a, "==",  codeExpr b]
    Lt  a b   -> group [codeExpr a, "<",   codeExpr b]
    Gt  a b   -> group [codeExpr a, ">",   codeExpr b]
    Le  a b   -> group [codeExpr a, "<=",  codeExpr b]
    Ge  a b   -> group [codeExpr a, ">=",  codeExpr b]
    Mux a b c -> group [codeExpr a, "?", codeExpr b, ":", codeExpr c] 
    where
    group :: [String] -> String
    group a = "(" ++ intercalate " " a ++ ")"

showConst :: Const -> String
showConst a = case a of
  Bool  True  -> "true"
  Bool  False -> "false"
  Int   a     -> show a
  Float a     -> show a

showConstType :: Const -> String
showConstType a = case a of
  Bool  _ -> "boolean"
  Int   _ -> "int"
  Float _ -> "float"
