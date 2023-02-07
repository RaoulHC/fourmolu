{-# LANGUAGE LambdaCase #-}

module FourmoluConfig.GenerateUtils where

import Control.Monad ((>=>))
import Data.List (intercalate, isSuffixOf, stripPrefix)
import Data.Map (Map)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import FourmoluConfig.ConfigData

{----- Helpers -----}

fieldTypesMap :: Map String FieldType
fieldTypesMap = Map.fromList [(fieldTypeName fieldType, fieldType) | fieldType <- allFieldTypes]

getFieldOptions :: Option -> Maybe [String]
getFieldOptions option = getOptions <$> Map.lookup (type_ option) fieldTypesMap
  where
    getOptions = \case
      FieldTypeEnum {enumOptions} -> map snd enumOptions
      FieldTypeADT {adtOptions} ->
        flip concatMap adtOptions $ \case
          ADTOptionLiteral s -> ["<code>" <> s <> "</code>"]
          ADTOptionRaw s -> [s]
          ADTOptionsFromType enum ->
            case enum `Map.lookup` fieldTypesMap of
              Just ty -> getOptions ty
              Nothing -> error $ "ADTOptionsFromType contains unknown type: " <> enum

-- | Render a HaskellValue for Haskell.
renderHs :: HaskellValue -> String
renderHs = \case
  HsExpr v -> v
  HsInt v -> show v
  HsBool v -> show v
  HsList vs -> "[" <> intercalate ", " (map renderHs vs) <> "]"

-- | Render a HaskellValue for YAML.
hs2yaml :: String -> HaskellValue -> String
hs2yaml hsType = \case
  HsExpr v ->
    fromMaybe (error $ "Could not render " <> hsType <> " value: " <> v) $
      case hsType `Map.lookup` fieldTypesMap of
        Just FieldTypeEnum {enumOptions} -> v `lookup` enumOptions
        Just FieldTypeADT {adtRender} -> v `lookup` adtRender
        Nothing -> Nothing
  HsInt v -> show v
  HsBool v -> if v then "true" else "false"
  HsList vs ->
    let hsType' =
          case (stripPrefix "[" >=> stripSuffix "]") hsType of
            Just s -> s
            Nothing -> error $ "Not a list type: " <> hsType
     in "[" <> intercalate ", " (map (hs2yaml hsType') vs) <> "]"

{----- Utilities -----}

-- | Like 'unlines', except without a trailing newline.
unlines_ :: [String] -> String
unlines_ = intercalate "\n"

indent :: String -> String
indent = indent' 1

indent' :: Int -> String -> String
indent' n = unlines_ . map (replicate (n * 2) ' ' <>) . lines

quote :: String -> String
quote s = "\"" <> s <> "\""

renderList :: [String] -> String
renderList = \case
  [] -> ""
  [s] -> s
  [s1, s2] -> s1 <> " or " <> s2
  ss -> intercalate ", " (init ss) <> ", or " <> last ss

stripSuffix :: String -> String -> Maybe String
stripSuffix suffix s =
  if suffix `isSuffixOf` s
    then Just $ take (length s - length suffix) s
    else Nothing

withFirst :: [a] -> [(Bool, a)]
withFirst = zip (True : repeat False)
