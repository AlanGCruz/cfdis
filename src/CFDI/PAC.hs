module CFDI.PAC where

import CFDI.Parser   (ParseError)
import CFDI.Renderer (toXML)
import CFDI.Types    (CFDI, Complement(..), PacStamp, complement, pacStamp)
import Data.Maybe    (fromMaybe)
import Data.Text     (Text)

class PAC p where
  getPacStamp :: CFDI -> p -> IO (Either StampError PacStamp)

data StampError
  = PacConnectionError
    { connErrMsg :: Text
    }
  | PacError
    { pacErrMsg  :: Text
    , pacErrCode :: Maybe Text
    }
  | PacHTTPError
    { pacHTTPCode :: Int
    , pacHTTPBody :: Text
    }
  | PacStampNotPresent
  | ParsePacResponseError
    { parsePacErrMsg :: Text
    }
  | ParsePacResponseXMLError
    { parseError :: ParseError
    }
  deriving (Eq, Show)

stamp :: PAC p => CFDI -> p -> IO (Either StampError CFDI)
stamp cfdi =
  fmap (fmap addStampToCFDI) . getPacStamp cfdi
  where
    addStampToCFDI stamp' =
      cfdi { complement = Just (complement' { pacStamp = Just stamp' }) }
    complement' = fromMaybe (Complement Nothing) $ complement cfdi
