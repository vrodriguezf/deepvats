from tsai.all import *
import nbs.orelm.utils as ut
import nbs.orelm.elm_torch as elm

class RLS_torch():
    def __init__(
            self,
            M,
            beta,
            forgettingFactor,
            print_flag = False
        ):
        self.M      = M
        self.RLS_e  = 0
        self.beta   = beta
        self.forgettingFactor = forgettingFactor
        self.print_flag = print_flag

    def fprint(self, mssg):
        if (self.print_flag):
            print("RLS_torch: " + mssg)

    def compute_kalman_gain(self, targets, H, Ht):
        numSamples = targets.shape[0]
        return torch.mm(
            torch.mm(self.M, Ht), 
            torch.inverse(
                self.forgettingFactor * torch.eye(numSamples) 
                + torch.mm(H, torch.mm(self.M, Ht))
            )  
        )
    def compute_prediction_error(self, targets, H):
        self.RLS_e = targets - torch.mm(H,self.beta)
        return self.RLS_e
    def compute_coefficients(self):
        self.beta = self.beta + torch.mm(self.RLS_k,self.RLS_e) 
        return self.beta
    def compute_inverse_covariance_matrix(self, H):
        self.M = 1/(self.forgettingFactor)*(self.M - torch.mm(self.RLS_k,torch.mm(H,self.M)))
        return self.M
    def compute_recursive_least_squares(self, targets, H, Ht):
        self.fprint("--> compute recursive least squares")
        self.RLS_k  = self.compute_kalman_gain(targets, H, Ht)
        self.RLS_e  = self.compute_prediction_error(self, targets, H)
        self.beta   = self.compute_coefficients()
        self.M      = self.compute_inverse_covariance_matrix(H)
        self.fprint("compute recursive least squares -->")
        return self.beta, self.M