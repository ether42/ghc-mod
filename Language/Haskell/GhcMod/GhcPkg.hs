{-# LANGUAGE BangPatterns, ScopedTypeVariables, TupleSections #-}
module Language.Haskell.GhcMod.GhcPkg (
    ghcPkgDbOpt
  , ghcPkgDbStackOpts
  , ghcDbStackOpts
  , ghcDbOpt
  , getPackageCachePaths
  ) where

import Config (cProjectVersion, cTargetPlatformString, cProjectVersionInt)
import Control.Applicative ((<$>))
import Data.List.Split (splitOn)
import Data.Maybe
import Exception (handleIO)
import Language.Haskell.GhcMod.Types
import System.Directory (doesDirectoryExist, getAppUserDataDirectory)
import System.FilePath ((</>))

ghcVersion :: Int
ghcVersion = read cProjectVersionInt

----------------------------------------------------------------

-- | Get options needed to add a list of package dbs to ghc-pkg's db stack
ghcPkgDbStackOpts :: [GhcPkgDb] -- ^ Package db stack
                  -> [String]
ghcPkgDbStackOpts dbs = ghcPkgDbOpt `concatMap` dbs

-- | Get options needed to add a list of package dbs to ghc's db stack
ghcDbStackOpts :: [GhcPkgDb] -- ^ Package db stack
               -> [String]
ghcDbStackOpts dbs = ghcDbOpt `concatMap` dbs

----------------------------------------------------------------

ghcPkgDbOpt :: GhcPkgDb -> [String]
ghcPkgDbOpt GlobalDb = ["--global"]
ghcPkgDbOpt UserDb   = ["--user"]
ghcPkgDbOpt (PackageDb pkgDb)
  | ghcVersion < 706 = ["--no-user-package-conf", "--package-conf=" ++ pkgDb]
  | otherwise        = ["--no-user-package-db",   "--package-db="   ++ pkgDb]

ghcDbOpt :: GhcPkgDb -> [String]
ghcDbOpt GlobalDb
  | ghcVersion < 706 = ["-global-package-conf"]
  | otherwise        = ["-global-package-db"]
ghcDbOpt UserDb
  | ghcVersion < 706 = ["-user-package-conf"]
  | otherwise        = ["-user-package-db"]
ghcDbOpt (PackageDb pkgDb)
  | ghcVersion < 706 = ["-no-user-package-conf", "-package-conf", pkgDb]
  | otherwise        = ["-no-user-package-db",   "-package-db",   pkgDb]

----------------------------------------------------------------

getPackageCachePaths :: FilePath -> Cradle -> IO [FilePath]
getPackageCachePaths sysPkgCfg crdl =
    catMaybes <$> resolvePackageConfig sysPkgCfg `mapM` cradlePkgDbStack crdl

-- TODO: use PkgConfRef
--- Copied from ghc module `Packages' unfortunately it's not exported :/
resolvePackageConfig :: FilePath -> GhcPkgDb -> IO (Maybe FilePath)
resolvePackageConfig sysPkgCfg GlobalDb = return $ Just sysPkgCfg
resolvePackageConfig _ UserDb = handleIO (\_ -> return Nothing) $ do
  appdir <- getAppUserDataDirectory "ghc"
  let dir = appdir </> (target_arch ++ '-':target_os ++ '-':cProjectVersion)
      pkgconf = dir </> "package.conf.d"
  exist <- doesDirectoryExist pkgconf
  return $ if exist then Just pkgconf else Nothing
 where
    [target_arch,_,target_os] = splitOn "-" cTargetPlatformString
resolvePackageConfig _ (PackageDb name) = return $ Just name
