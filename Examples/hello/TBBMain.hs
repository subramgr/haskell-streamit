{-# LANGUAGE TemplateHaskell #-}
module Main (main) where

import HelloWorld (helloWorld)
import Language.StreamIt

main = genTBB "HelloWorld" helloWorld