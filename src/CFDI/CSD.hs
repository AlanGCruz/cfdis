{-# LANGUAGE OverloadedStrings #-}

module CFDI.CSD
  ( CsdCerData(..)
  , getCsdCerData
  , csdKeyToPem
  , signCFDIWith
  , signWithCSD
  ) where

import CFDI.Chain                (originalChain)
import CFDI.Types                (CFDI, signature)
import Control.Exception         (ErrorCall, catch, evaluate)
import Data.ByteString           (ByteString)
import Data.ByteString.Base64    (encode)
import Data.Maybe                (fromJust)
import Data.Text                 (Text, concat, empty, pack, split, unpack)
import Data.Text.Encoding        (decodeUtf8, encodeUtf8)
import Data.Time.LocalTime       (LocalTime)
import Data.Time.Format          (defaultTimeLocale, parseTimeM)
import Prelude            hiding (concat)
import System.Exit               (ExitCode(..))
import System.Process.ByteString (readProcessWithExitCode)
import qualified Util as U       (split)

data CsdCerData = CsdCerData
  { cerExpiresAt :: LocalTime
  , cerNumber    :: Text
  , cerToText    :: Text
  } deriving (Eq, Show)

-- TODO: Rewrite these methods using OpenSSL module. At the time of writting
-- this I couldn't figure out how to use it.

getCsdCerData :: FilePath -> IO (Either Text CsdCerData)
getCsdCerData cerPath =
  getPem cerPath >>= eitherErrOrContinue (\pem ->
    getSerial pem >>= eitherErrOrContinue (\serial ->
      getEndDate pem >>= eitherErrOrContinue (\endDate ->
        return . Right . CsdCerData endDate serial $ sha1 pem)))
  where
    eitherErrOrContinue = either (return . Left)
    sha1 = concat . init . init . tail . split (== '\n')

csdKeyToPem :: FilePath -> String -> IO (Either Text Text)
csdKeyToPem keyPath keyPass =
  runOpenSSL ("pkcs8 -inform DER -in " ++ keyPath ++ " -passin " ++ pass) empty
  where
    pass = "pass:" ++ keyPass

signCFDIWith :: FilePath -> CFDI -> IO (Either Text CFDI)
signCFDIWith csdPemPath cfdi =
  fmap (fmap addSignatureToCFDI) . signWithCSD csdPemPath $ originalChain cfdi
  where
    addSignatureToCFDI sig = cfdi { signature = sig }

signWithCSD :: FilePath -> Text -> IO (Either Text Text)
signWithCSD csdPemPath =
  fmap (either (Left . decodeUtf8) (Right . decodeUtf8 . encode))
    . runOpenSSL_ ("dgst -sha1 -sign " ++ csdPemPath)

-- Helpers

getPem :: FilePath -> IO (Either Text Text)
getPem cerPath =
  runOpenSSL ("x509 -inform DER -outform PEM -in " ++ cerPath) empty

getSerial :: Text -> IO (Either Text Text)
getSerial pem =
  parseSerial <$> runOpenSSL "x509 -noout -serial" pem
  where
    parseSerial = fmap (pack . odds . unpack . head . tail . split (== '='))
    odds [] = []
    odds [x] = []
    odds (e1 : e2 : xs) = e2 : odds xs

getEndDate :: Text -> IO (Either Text LocalTime)
getEndDate pem = catch
  (runOpenSSL "x509 -noout -enddate" pem >>= evaluate . parseEndDate)
  handleErr
  where
    handleErr :: ErrorCall -> IO (Either Text LocalTime)
    handleErr e = return $ Left "Formato de fecha de expiración inválido"
    parseEndDate = (>>= parseTimeM True defaultTimeLocale format . unpack)
    format = "notAfter=%b %d %H:%M:%S %Y %Z"

runOpenSSL :: String -> Text -> IO (Either Text Text)
runOpenSSL command =
  fmap (either (Left . decodeUtf8) (Right . decodeUtf8)) . runOpenSSL_ command

runOpenSSL_ :: String -> Text -> IO (Either ByteString ByteString)
runOpenSSL_ command stdin = do
  (exitCode, stdout, stderr) <- readProcessWithExitCode "openssl" args bsStdin
  return $ case exitCode of
    ExitSuccess   -> Right stdout
    ExitFailure _ -> Left  stderr
  where
    args = U.split ' ' command
    bsStdin = encodeUtf8 stdin
