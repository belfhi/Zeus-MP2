#include "rtchem.def"
!=======================================================================
!
!    \\\\\\\\\\      B E G I N   S U B R O U T I N E      //////////
!    //////////             G P _ U P D A T E             \\\\\\\\\\
!
!
!           Updates the gravitational potential of the dark matter
!           halo on the moving grid of the supernova2 problem
!
!           written by Daniel Whalen 11-14-07
!             
!             
!=======================================================================
      subroutine gp_update
!
      use real_prec
      use config
      use param
      use field
      use bndry
      use chem
      use grid
      use root
      use scratch
      use cons
#ifdef MPI_USED
      use mpiyes
#else
      use mpino
#endif
      use mpipar
!
      implicit none
!
      integer  :: i, j, k, z, l, index, nlines(9), nhalo, nbins
      real(rl) :: amtemp, vexpanmax
      real(rl) :: logr, logrmin, logrmax, r1, r2, r, &
                  rdef, loggp 
      real(rl), dimension(200) :: dtable,Ttable,vrtable,rtable, &
         etable,HItable,HIItable,eltable,HeItable,HeIItable,HeIIItable, &
         HMtable,H2Itable,H2IItable,gptable
      character*11 :: tablefile
      common /inflow/ vexpanmax,amtemp,dtable,Ttable,vrtable,rtable, &
                      nhalo,nlines,etable,HItable,HIItable,eltable, &
                      HeItable,HeIItable,HeIIItable,HMtable,H2Itable, &
                      H2IItable,gptable
!
      nbins = nlines(nhalo) - 1
      vexpanmax=10.
      if (vexpanmax .ne. 0.) then
!          print*,"gptable is: ",(gptable(i), i=1,200)
      do k=ks,ke
        do j=js,je
          do i=i-2,ie+2
          do l = 1,nbins
             if (x1b(i)/cmpc .ge. rtable(l  )  .and. &
                 x1b(i)/cmpc .lt. rtable(l+1)) index = l
          enddo
          r = x1b(i)/cmpc
          if (r .lt. rtable(1)                 ) then
            index = 1
!            loggp    = gptable   (index)
            logr     = dlog10(r)
            r1       = -99.0
            r2       = dlog10(rtable(index))
            rdef     = r2 - r1
            loggp    = (logr-r1)*gptable(index)/rdef
          else if (r .gt. rtable(nlines(nhalo))) then
            index = nlines(nhalo)
            loggp    = gptable   (index)
          else
            logr  = dlog10(r)
            r1    = dlog10(rtable(index  ))
            r2    = dlog10(rtable(index+1))
            rdef  = r2 - r1
            loggp    = gptable   (index  ) + (logr-r1) &
                     *(gptable   (index+1) - gptable   (index))/rdef
          endif
          gp  (i,j,k  ) = -10.0**loggp
!          print*,"index is: ",index 
!          print*,"gp is: ",gp(i,j,k)
          enddo
        enddo
      enddo
!          stop
!
      endif !vexpanmax
!
      return
      end
!
!=======================================================================
!
!    \\\\\\\\\\        E N D   S U B R O U T I N E        //////////
!    //////////             G P _ U P D A T E             \\\\\\\\\\
!
!=======================================================================
!
