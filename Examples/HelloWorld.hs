module Main (main) where

import Control.Monad
import Language.StreamIt

intSource :: Filter ()
intSource = do
  x <- int "x"
  init' $ do
    x <== 0

  work (1, 0, 0) $ do
    incr x
    push(ref x)

intPrinter :: Filter ()
intPrinter = do
  work (0, 1, 0) $ do
    println $ pop'

helloWorld :: StreamIt ()
helloWorld = pipeline "void->void" "HelloWorld" $ do
  add "void->int" "IntSource" intSource
  add "int->void" "IntPrinter" intPrinter

main :: IO ()
main = runStreamIt "HelloWorld.str" helloWorld
