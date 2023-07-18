-- We setup the environment to invoke certain terminals of interest.
-- This assumes appropriate definitions exist in the current environment
-- for the terminals of interest.
{-# LANGUAGE ScopedTypeVariables #-}
module VerifyOutput where

import Verify

import Graphics.Vty
import Graphics.Vty.Platform.Unix.Settings
import Graphics.Vty.Platform.Unix.Output

import Verify.Graphics.Vty.Image
import Verify.Graphics.Vty.Output

import Control.Monad

import qualified System.Console.Terminfo as Terminfo
import System.Posix.IO

tests :: IO [Test]
tests = concat <$> forM terminalsOfInterest (\termName -> do
    -- check if that terminfo exists
    -- putStrLn $ "testing end to end for terminal: " ++ termName
    mti <- try $ Terminfo.setupTerm termName
    case mti of
        Left (_ :: SomeException) -> return []
        Right _ -> return [ verify ("verify " ++ termName ++ " could output a picture")
                                   (smokeTestTermNonMac termName)
                          ]
    )

smokeTestTermNonMac :: String -> Image -> Property
smokeTestTermNonMac termName i = liftIOResult $ do
    smokeTestTerm termName i

smokeTestTerm :: String -> Image -> IO Result
smokeTestTerm termName i = do
    nullOut <- openFd "/dev/null" WriteOnly Nothing defaultFileFlags
    def <- defaultSettings
    t <- buildOutput $ def
        { settingOutputFd = nullOut
        , settingTermName = termName
        , settingColorMode = NoColor
        }
    -- putStrLn $ "context color count: " ++ show (contextColorCount t)
    reserveDisplay t
    dc <- displayContext t (100,100)
    -- always show the cursor to produce tests for terminals with no
    -- cursor support.
    let pic = (picForImage i) { picCursor = Cursor 0 0 }
    outputPicture dc pic
    setCursorPos t 0 0
    when (supportsCursorVisibility t) $ do
        hideCursor t
        showCursor t
    releaseDisplay t
    releaseTerminal t
    closeFd nullOut
    return succeeded

