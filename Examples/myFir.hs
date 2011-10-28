module Main (main) where

import Language.StreamIt

fir :: Filter ()
fir = do
  result <- float "result"
  tmp <- int "tmp"

  result <== ref result
  work (1, 0, 0) $ do
    moo <- int "moo"
    moo <== ref moo

  pop
  push $ ref result

main :: IO ()
main = filter' "myFir" fir