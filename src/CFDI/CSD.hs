module CFDI.CSD where

import Data.ByteString           (ByteString, empty)
import Data.ByteString.Base64    (encode)
import System.Exit               (ExitCode(..))
import System.Process.ByteString (readProcessWithExitCode)

-- TODO: Rewrite these methods using module OpenSSL. At the time of writting
-- this I couldn't figure out how to use it.

csdKeyToPem :: FilePath -> String -> IO (Either ByteString ByteString)
csdKeyToPem keyPath keyPass = do
  let pass = "pass:" ++ keyPass
  let args = ["pkcs8", "-inform", "DER", "-in", keyPath, "-passin", pass]
  (exitCode, stdout, stderr) <- readProcessWithExitCode "openssl" args empty
  case exitCode of
    ExitSuccess   -> return $ Right stdout
    ExitFailure _ -> return $ Left stderr

signWithCSD :: FilePath -> String -> IO (Either ByteString ByteString)
signWithCSD csdPemPath str = do
  let args = ["dgst", "-sha1", "-sign", csdPemPath]
  (exitCode, stdout, stderr) <- readProcessWithExitCode "openssl" args empty
  case exitCode of
    ExitSuccess   -> return . Right $ encode stdout
    ExitFailure _ -> return $ Left stderr
